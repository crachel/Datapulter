//
//  B2.swift
//
//
//  Created by Craig Rachel on 12/5/18.
//

import UIKit
import os.log
import Promises
import Photos

class B2: Provider {

    //MARK: Properties

    typealias NetworkCompletionHandler = (Data?, URLResponse?, Error?) -> Void
    
    struct Defaults {
        static let apiMainURL          = "https://api.backblazeb2.com"
        static let authorizeAccountUrl = URL(string: "https://api.backblazeb2.com/b2api/v2/b2_authorize_account")
    
        static let maxParts            = 10_000
        static let defaultUploadCutoff = 200 * 1_000 * 1_000
        static let defaultChunkSize    = 100 * 1_000 * 1_000
    }
    
    var account: String
    var key: String
    var bucket: String
    var accountId: String
    var bucketId: String
    var versions: Bool
    var harddelete: Bool
    
    var pool = SynchronizedQueue<GetUploadURLResponse>()
    
    var authorizationToken: String? {
        get {
            if let result = KeychainHelper.get(account: account),
                let tokenData = result[kSecValueData as String] as? Data,
                let token = String(data: tokenData, encoding: .utf8) {
                return token
            }
            
            return nil
        }
    }
    
    var apiUrl: String {
        get {
            if let result = KeychainHelper.get(account: account),
                let url = result[kSecAttrServer as String] as? String {
                return url
            }
            
            return Defaults.apiMainURL // keeps urlsessiontask from failing
        }
    }
    
    var recommendedPartSize: Int {
        get {
            return UserDefaults.standard.integer(forKey: PropertyKey.recommendedPartSize)
        }
    }
    
    var authorizeAccountResponse: AuthorizeAccountResponse? {
        didSet {
            UserDefaults.standard.set(authorizeAccountResponse!.recommendedPartSize, forKey: PropertyKey.recommendedPartSize)
            if(KeychainHelper.update(account: account, value: authorizeAccountResponse!.authorizationToken, server: authorizeAccountResponse!.apiUrl)) {
                print("B2.authorizationToken saved to keychain")
            } else {
                print("Problem saving B2.authorizationToken to keychain")
            }
        }
    }
    
    //MARK: Types
    
    enum B2Error: String, Error {
        // required. must match codes EXACTLY as defined by API
        case bad_request         // 400
        case unauthorized        // 401
        case bad_auth_token      // 401
        case expired_auth_token  // 401
        case service_unavailable // 503
        
        case unmatchedError
    }
    
    struct Endpoints {
        static let getUploadUrl     = Endpoint(path: "/b2api/v2/b2_get_upload_url")
        static let getUploadPartUrl = Endpoint(path: "/b2api/v2/b2_get_upload_part_url")
        static let startLargeFile   = Endpoint(path: "/b2api/v2/b2_start_large_file")
        static let finishLargeFile  = Endpoint(path: "/b2api/v2/b2_finish_large_file")
    }

    struct HTTPHeaders {
        static let prefix            = "X-Bz-Info-"
        static let authorization     = "Authorization"
        static let fileName          = "X-Bz-File-Name"
        static let contentLength     = "Content-Length"
        static let contentTypeValue  = "b2/x-auto"
        static let contentType       = "Content-Type"
        static let timeKey           = "src_last_modified_millis"
        static let time              = prefix + timeKey
        static let sha1Key           = "large_file_sha1"
        static let sha1              = "X-Bz-Content-Sha1"
        static let mimeType          = "application/json"
    }
    
    struct PropertyKey {
        static let account             = "account"
        static let key                 = "key"
        static let bucket              = "bucket"
        static let versions            = "versions"
        static let harddelete          = "harddelete"
        static let uploadList          = "uploadList"
        static let accountId           = "accountId"
        static let bucketId            = "bucketId"
        
        static let authorizationToken  = "authorizationToken"
        static let apiUrl              = "apiUrl"
        static let recommendedPartSize = "recommendedPartSize"
    }
    
    //MARK: Initialization
    
    init(name: String, account: String, key: String, bucket: String, versions: Bool, harddelete: Bool, accountId: String, bucketId: String, remoteFileList: [String: [String:Any]], assetsToUpload: Set<PHAsset>) {
        self.account = account
        self.key = key
        self.bucket = bucket
        self.versions = versions
        self.harddelete = harddelete
        self.accountId = accountId
        self.bucketId = bucketId
        
        super.init(name: name, backend: .Backblaze, remoteFileList: remoteFileList, assetsToUpload: [])
    }
    
    //MARK: Public methods
    
    override func getUrlRequest(_ asset: PHAsset) -> Promise<(URLRequest?, URL?)> {
        
        if (asset.size > Defaults.defaultUploadCutoff ) {
            //startLargeFile(asset)
            return Promise(providerError.foundNil) //need to return here so we don't try to process large file anyway
        } else {
            //return Promise(providerError.foundNil)
        }
        
        if (pool.count > 3) {
            if let data = pool.dequeue() {
                print("uploadUrl from Pool: \(data.uploadUrl)")
                
                print("got url out of pool")
                
                return self.prepareRequest(from: asset, with: data)
            }
        }
        
        var uploadData: Data
        
        do {
            uploadData = try JSONEncoder().encode(GetUploadURLRequest(bucketId: bucketId))
        } catch {
            return Promise(error)
        }
        return self.fetch(from: Endpoints.getUploadUrl, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
        //return self.apiOperation(on: Endpoints.getUploadUrl, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
        //return self.getUploadUrlApi().recover { error -> Promise<(Data?, URLResponse?)> in
            switch error {
            case B2Error.bad_auth_token, B2Error.expired_auth_token:
                print("[getUploadUrlApi] bad or expired auth token. attempting refresh then retrying API call.")
                return self.authorizeAccount().then { data, _ in
                    Utility.objectIsType(object: data, someObjectOfType: Data.self)
                }.then { data in
                    try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
                }.then { parsedResult in
                    self.authorizeAccountResponse = parsedResult
                }.then {
                    self.fetch(from: Endpoints.getUploadUrl, with: uploadData) // succesfully authorized now retry call
                    //self.apiOperation(on: Endpoints.getUploadUrl, with: uploadData) // succesfully authorized now retry call
                }
            default:
                return Promise(error)
            }
        }.then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            try JSONDecoder().decode(GetUploadURLResponse.self, from: data)
        }.then { result in
            self.prepareRequest(from: asset, with: result)
        }
        
    }
    
    override func getUploadObject<GetUploadURLResponse>(_ asset: PHAsset,_ urlPoolObject: GetUploadURLResponse) -> Promise<(UploadObject<GetUploadURLResponse>?)> {
        
        return Promise(UploadObject(asset: asset, urlPoolObject: urlPoolObject))
    }
    
    override func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        guard let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString() else {
            return Promise(providerError.preparationFailed)
        }
        
        guard let url = Defaults.authorizeAccountUrl else {
            return Promise(providerError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.get
        urlRequest.setValue("Basic \(authNData)", forHTTPHeaderField: HTTPHeaders.authorization)
        
        return fetch(from: urlRequest)
    }
    
    //MARK: Private methods
    
    private func prepareRequest(from asset: PHAsset, with result: GetUploadURLResponse) -> Promise<(URLRequest?, URL?)> {

        /*
        let (count, capacity) = dispatchQueue.sync {
            return (urlPool.count, urlPool.capacity)
        }
        
        // add to urlPool, if there's room
        dispatchQueue.async(flags: .barrier) {
            if (count < (capacity - 1)) {
                self.urlPool.append(result)
                print("prepareRequest: appended result to urlPool. Count: \(count)")
            }
        }*/
        
        if (pool.count < 50) {
            pool.enqueue(result)
            print("prepareRequest: appended result to pool. Count: \(pool.count)")
        }
        
        return Promise { fulfill, reject in
            var urlRequest: URLRequest
            urlRequest = URLRequest(url: result.uploadUrl)
            urlRequest.httpMethod = HttpMethod.post
            urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
            urlRequest.setValue(HTTPHeaders.contentTypeValue, forHTTPHeaderField: HTTPHeaders.contentType)
            
            urlRequest.setValue(String(asset.size), forHTTPHeaderField: HTTPHeaders.contentLength)
            
            if let fileName = asset.percentEncodedFilename {
                urlRequest.setValue(fileName, forHTTPHeaderField: HTTPHeaders.fileName)
            } else {
                reject (providerError.foundNil)
            }
            
            if let unixCreationDate = asset.creationDate?.millisecondsSince1970  {
                urlRequest.setValue(String(unixCreationDate), forHTTPHeaderField: HTTPHeaders.time)
            } else {
                reject(providerError.foundNil)
            }
            
            Utility.getData(from: asset) { data, url in
                
                urlRequest.setValue(data.sha1, forHTTPHeaderField: HTTPHeaders.sha1)
            
                fulfill((urlRequest, url))
            }
        }
    }
    

    private func startLargeFile(_ asset: PHAsset) -> Promise<(Data?, URLResponse?)> {
        guard let fileName = asset.originalFilename else {
            
            return Promise(providerError.preparationFailed)
        }
        
        var uploadData: Data
        
        let request = StartLargeFileRequest(bucketId: bucketId,
                                            fileName: fileName,
                                            contentType: HTTPHeaders.contentTypeValue)
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            return Promise(error)
        }
        return self.fetch(from: Endpoints.startLargeFile, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
        //return self.apiOperation(on: Endpoints.startLargeFile, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
        //return self.startLargeFileApi(fileName).recover { error -> Promise<(Data?, URLResponse?)> in
            switch error {
            case B2Error.bad_auth_token, B2Error.expired_auth_token:
                print("[startLargeFileApi] bad or expired auth token. attempting refresh then retrying API call.")
                return self.authorizeAccount().then { data, _ in
                    Utility.objectIsType(object: data, someObjectOfType: Data.self)
                }.then { data in
                    try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
                }.then { parsedResult in
                    self.authorizeAccountResponse = parsedResult
                }.then {
                    self.fetch(from: Endpoints.startLargeFile, with: uploadData) // retry call
                    //self.apiOperation(on: Endpoints.startLargeFile, with: uploadData) // retry call
                }
            default:
                return Promise(error)
            }
        }.then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            try JSONSerialization.jsonObject(with: data) as! [String: Any]
        }.then { parsedResult in
            self.processLargeFile(asset, parsedResult["fileId"] as! String)
        }.then { fileId, partSha1Array in
            try JSONEncoder().encode(FinishLargeUploadRequest(fileId: fileId, partSha1Array: partSha1Array))
        }.then { uploadData in
            self.fetch(from: Endpoints.finishLargeFile, with: uploadData)
            //self.finishLargeFile(fileId, partSha1Array)
        }
    }
    //private func uploadPart(_ result: GetUploadPartURLResponse,_ data: Data,_ url: URL,_ partNumber: Int) {
    private func uploadPart(_ result: GetUploadPartURLResponse,_ data: Data,_ url: URL,_ partNumber: Int) -> Promise<(Data?, URLResponse?)> {
        var urlRequest: URLRequest
        urlRequest = URLRequest(url: result.uploadUrl)
        urlRequest.httpMethod = HttpMethod.post
        urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
        
        urlRequest.setValue(String(partNumber), forHTTPHeaderField: "X-Bz-Part-Number")
        
        urlRequest.setValue(String(data.count), forHTTPHeaderField: HTTPHeaders.contentLength)
        
        urlRequest.setValue(data.sha1, forHTTPHeaderField: HTTPHeaders.sha1)
        
        return fetch(from: urlRequest, with: data)
    }
    
    private func processLargeFile(_ asset: PHAsset,_ fileId: String) -> Promise<(String, [String])> {
        return Promise { fulfill, _ in
            // handle large upload
            let payloadDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
            let payloadFileURL = payloadDirURL.appendingPathComponent(UUID().uuidString)

            //open temp dir for writing from stream. means user needs const.defaultchunksize
            //available space. could be problem. need to check for this eventually
            guard let outputStream = OutputStream(url: payloadFileURL, append: false) else {
                return
            }
           
            var partSha1Array = [String]()
            var part = 0
            
            Utility.getData(from: asset) { _, url in
                if let inputStream = InputStream.init(url: url) {
                    inputStream.open()
                    outputStream.open()
                    
                    var buffer = [UInt8](repeating: 0, count: self.recommendedPartSize)
                    var bytes = 0
                    
                    func readBytes() {
                        
                        bytes = inputStream.read(&buffer, maxLength: self.recommendedPartSize)
                        
                        if bytes > 0 && part < Defaults.maxParts {
                            part += 1
                            let data = Data(bytes: buffer, count: bytes)
                            partSha1Array.append(data.sha1)
                            let written = outputStream.write(buffer, maxLength: bytes)
                            
                            print("bytes written to outputStream: \(written)")
                            preparePart(data).then { _, _ in
                                readBytes()
                            }
                        } else {
                            do {
                                print("processLargeFile: Trying to remove payloadFileURL...", terminator:"")
                                try FileManager.default.removeItem(at: payloadFileURL)
                                print("done")
                            } catch let error as NSError {
                                print("failed")
                                print("Error: \(error.domain)")
                            }
                            
                            inputStream.close()
                            outputStream.close()
                            
                            fulfill((fileId, partSha1Array))
                        }
                    }
                    readBytes()
                    
                    func preparePart(_ data: Data) -> Promise<(Data?, URLResponse?)> {
                        var uploadData: Data
                        
                        do {
                            uploadData = try JSONEncoder().encode(GetUploadPartURLRequest(fileId: fileId))
                        } catch {
                            return Promise(error)
                        }
                        
                        return self.fetch(from: Endpoints.getUploadPartUrl, with: uploadData).then { data, response in
                            Utility.objectIsType(object: data, someObjectOfType: Data.self)
                        }.then { data in
                            try JSONDecoder().decode(GetUploadPartURLResponse.self, from: data)
                        }.then { parsedResponse in
                            self.uploadPart(parsedResponse, data, payloadFileURL, part)
                        }.catch { error in
                            print("\(error)")
                        }
                    }
                }
            }
        }
    }
    
    private func fetch(from urlRequest: URLRequest, with uploadData: Data? = nil) -> Promise<(Data?, URLResponse?)> {
        return Promise { fulfill, reject in
            
            let completionHandler: NetworkCompletionHandler = { data, response, error in
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                if let error = error {
                    reject(error)
                }
                
                if let response = response as? HTTPURLResponse,
                    let mimeType = response.mimeType,
                    mimeType == HTTPHeaders.mimeType,
                    let data = data {
                    
                    if (response.statusCode == 200) {
                        fulfill((data, response))
                    } else if (400...401).contains(response.statusCode) {
                        do {
                            let jsonerror = try JSONDecoder().decode(JSONError.self, from: data)
                            reject (B2Error(rawValue: jsonerror.code) ?? B2Error.unmatchedError)
                        } catch {
                            reject (error) // handled status code but unknown problem decoding JSON
                        }
                    } else {
                        reject (providerError.unhandledStatusCode) // unhandled status code
                    }
                } else {
                    reject (providerError.invalidResponse)
                }
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            if (urlRequest.httpMethod == HttpMethod.post) {
                URLSession.shared.uploadTask(with: urlRequest, from:uploadData, completionHandler: completionHandler).resume()
            } else if (urlRequest.httpMethod == HttpMethod.get) {
                URLSession.shared.dataTask(with: urlRequest, completionHandler: completionHandler).resume()
            }
       }
    }
    
    private func fetch(from endpoint: Endpoint, with uploadData: Data? = nil) -> Promise<(Data?, URLResponse?)> {
        print("*****CALLED FETCH")
        guard let url = URL(string: "\(apiUrl)\(endpoint.path)") else {
            return Promise(providerError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = endpoint.method
        
        if (authorizationToken == nil) {
            return Promise(B2Error.bad_auth_token)
        } else {
            urlRequest.setValue(authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
        }
        return Promise { fulfill, reject in
            
            let completionHandler: NetworkCompletionHandler = { data, response, error in
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                if let error = error {
                    reject(error)
                }
                
                if let response = response as? HTTPURLResponse,
                    let mimeType = response.mimeType,
                    mimeType == HTTPHeaders.mimeType,
                    let data = data {
                    
                    if (response.statusCode == 200) {
                        fulfill((data, response))
                    } else if (400...401).contains(response.statusCode) {
                        do {
                            let jsonerror = try JSONDecoder().decode(JSONError.self, from: data)
                            reject (B2Error(rawValue: jsonerror.code) ?? B2Error.unmatchedError)
                        } catch {
                            reject (error) // handled status code but unknown problem decoding JSON
                        }
                    } else {
                        reject (providerError.unhandledStatusCode) // unhandled status code
                    }
                } else {
                    reject (providerError.invalidResponse)
                }
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            if (urlRequest.httpMethod == HttpMethod.post) {
                URLSession.shared.uploadTask(with: urlRequest, from:uploadData, completionHandler: completionHandler).resume()
            } else if (urlRequest.httpMethod == HttpMethod.get) {
                URLSession.shared.dataTask(with: urlRequest, completionHandler: completionHandler).resume()
            }
        }
    }
    
    //MARK: NSCoding
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(account, forKey: PropertyKey.account)
        aCoder.encode(key, forKey: PropertyKey.key)
        aCoder.encode(bucket, forKey: PropertyKey.bucket)
        aCoder.encode(versions, forKey: PropertyKey.versions)
        aCoder.encode(harddelete, forKey: PropertyKey.harddelete)
        aCoder.encode(accountId, forKey: PropertyKey.accountId)
        aCoder.encode(bucketId, forKey: PropertyKey.bucketId)
        aCoder.encode(remoteFileList, forKey: PropertyKey.remoteFileList)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // These are required. If we cannot decode, the initializer should fail.
        guard
            let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String,
            let account = aDecoder.decodeObject(forKey: PropertyKey.account) as? String,
            let key = aDecoder.decodeObject(forKey: PropertyKey.key) as? String,
            let bucket = aDecoder.decodeObject(forKey: PropertyKey.bucket) as? String,
            let accountId = aDecoder.decodeObject(forKey: PropertyKey.accountId) as? String,
            let bucketId = aDecoder.decodeObject(forKey: PropertyKey.bucketId) as? String,
            let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as? [String: [String:Any]]
        else
        {
            os_log("Unable to decode a B2 object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let versions = aDecoder.decodeBool(forKey: PropertyKey.versions)
        let harddelete = aDecoder.decodeBool(forKey: PropertyKey.harddelete)
        
        
        // Must call designated initializer.
        self.init(name: name, account: account, key: key, bucket: bucket, versions: versions, harddelete: harddelete, accountId: accountId, bucketId: bucketId, remoteFileList: remoteFileList, assetsToUpload: [])
    }
 
}
