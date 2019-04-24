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
        static let maxParts     = 10_000
        static let uploadCutoff = 200 * 1_000 * 1_000
        static let chunkSize    = 100 * 1_000 * 1_000
        
        static let poolMinimum  = 3
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
            
            return "https://api.backblazeb2.com" // fixeme: keeps urlsessiontask from failing
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
        case cap_exceeded        // 403
        case method_not_allowed  // 405
        case request_timeout     // 408
        case service_unavailable // 503
        
        case unmatchedError
    }
    
    struct Endpoints {
        static let authorizeAccount: Endpoint = {
            var components = URLComponents()
            components.scheme = "https"
            components.host   = "api.backblazeb2.com"
            components.path   = "/b2api/v2/b2_authorize_account"
            return Endpoint(components: components, method: HTTPMethod.get)
        }()
        
        // host for these endpoints not known at compile time
        static let finishLargeFile  = Endpoint(path: "/b2api/v2/b2_finish_large_file")
        static let getUploadUrl     = Endpoint(path: "/b2api/v2/b2_get_upload_url")
        static let getUploadPartUrl = Endpoint(path: "/b2api/v2/b2_get_upload_part_url")
        static let startLargeFile   = Endpoint(path: "/b2api/v2/b2_start_large_file")
        static let uploadFile       = Endpoint(path: "/b2api/v2/b2_upload_file")
        static let uploadPart       = Endpoint(path: "/b2api/v2/b2_upload_part")
    }

    struct HTTPHeaders {
        static let prefix            = "X-Bz-Info-"
        static let authorization     = "Authorization"
        static let fileName          = "X-Bz-File-Name"
        static let partNumber        = "X-Bz-Part-Number"
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
    
    init(name: String, account: String, key: String, bucket: String, versions: Bool, harddelete: Bool, accountId: String, bucketId: String, remoteFileList: [String: Data], assetsToUpload: Set<PHAsset>) {
        self.account = account
        self.key = key
        self.bucket = bucket
        self.versions = versions
        self.harddelete = harddelete
        self.accountId = accountId
        self.bucketId = bucketId
        
        super.init(name: name, backend: .Backblaze, remoteFileList: remoteFileList, assetsToUpload: [], largeFiles: [])
    }
    
    //MARK: Public methods
    
    override func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        guard let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString() else {
            return Promise(providerError.preparationFailed)
        }
        
        guard let url = Endpoints.authorizeAccount.components.url else {
            return Promise(providerError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.get
        urlRequest.setValue("Basic \(authNData)", forHTTPHeaderField: HTTPHeaders.authorization)
        
        return fetch(from: urlRequest)
    }
    
    override func getURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, URL?)> {
        
        if (asset.size > Defaults.uploadCutoff ) {
            startLargeFile(asset)
            
            return Promise(providerError.largeFile) //need to return here so we don't try to process large file anyway
        }
    
        if (pool.count > Defaults.poolMinimum) {
            if let data = pool.dequeue() {
                return self.uploadFileRequest(from: asset, with: data)
            }
        }
        
        var uploadData: Data
        do {
            uploadData = try JSONEncoder().encode(GetUploadURLRequest(bucketId: bucketId))
        } catch {
            return Promise(error)
        }
        
        return self.fetch(from: Endpoints.getUploadUrl, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
            self.recover(from: error, retry: Endpoints.getUploadUrl, with: uploadData)
        }.then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            try JSONDecoder().decode(GetUploadURLResponse.self, from: data)
        }.then { result in
            self.uploadFileRequest(from: asset, with: result)
        }
    }

    override func decodeURLResponse(response: HTTPURLResponse,data: Data,task: URLSessionTask) {
    
        if (response.statusCode == 200) {
            if let originalRequest = task.originalRequest,
                let allHeaders = originalRequest.allHTTPHeaderFields,
                let originalUrl = originalRequest.url {
                
                if (originalUrl.path.contains(Endpoints.uploadFile.components.path)) { // alternative could be [URLRequest:Endpoint]
                    var uploadFileResponse: UploadFileResponse
                    
                    do {
                        uploadFileResponse = try JSONDecoder().decode(UploadFileResponse.self, from: data)
                    } catch {
                        return
                    }
                    
                    if let token = allHeaders["Authorization"] {
                        let getUploadURLResponse = GetUploadURLResponse(bucketId: uploadFileResponse.bucketId, uploadUrl: originalUrl, authorizationToken: token)
                        
                        pool.enqueue(getUploadURLResponse)
                        print("provider.uploadDidComplete -> appended result to pool. Count: \(pool.count)")
                    }
                } else if (originalUrl.path.contains(Endpoints.startLargeFile.components.path)) {
                    // this is startlargefile response
                    // build [fileId: someStruct] here
                    // kick off getuploadparturl for part #1
                    var startLargeFileResponse: StartLargeFileResponse
                    
                    do {
                        startLargeFileResponse = try JSONDecoder().decode(StartLargeFileResponse.self, from: data)
                    } catch {
                        print (error)
                        print (String(data: data, encoding: .utf8))
                        return
                    }
                    
                    print ("startLargeFileResponse is good. fileid: \(startLargeFileResponse.fileId)")
                } else if (originalUrl.path.contains(Endpoints.getUploadPartUrl.components.path)) {
                    var getUploadPartURLResponse: GetUploadPartURLResponse
                    
                    do {
                        getUploadPartURLResponse = try JSONDecoder().decode(GetUploadPartURLResponse.self, from: data)
                    } catch {
                        print (error)
                        print (String(data: data, encoding: .utf8))
                        return
                    }
                    
                    // hey i've got an uploadpartresponse, now what?
                    // look for a dictionary keyed by fileId probably [fileId:someStruct]
                    // uploadPart(getUploadPartURLResponse)
                } else if (originalUrl.path.contains(Endpoints.uploadPart.components.path)) {
                    var uploadPartResponse: UploadPartResponse
                    
                    do {
                        uploadPartResponse = try JSONDecoder().decode(UploadPartResponse.self, from: data)
                    } catch {
                        print (error)
                        print (String(data: data, encoding: .utf8))
                        return
                    }
                    // fileId  partNumber  contentLength  contentSha1  uploadTimestamp
                    // a part uploaded. am i done. yes? finishlargefile. no? get another uploadparturl
                } else if (originalUrl.path.contains(Endpoints.finishLargeFile.components.path)) {
                    var finishLargeFileResponse: FinishLargeFileResponse
                    
                    do {
                        finishLargeFileResponse = try JSONDecoder().decode(FinishLargeFileResponse.self, from: data)
                    } catch {
                        print (error)
                        print (String(data: data, encoding: .utf8))
                        return
                    }
                   
                }
            }
        } else {
            var jsonError: JSONError
            
            do {
                jsonError = try JSONDecoder().decode(JSONError.self, from: data)
            } catch {
                return
            }
            
            switch jsonError.code {
            case B2Error.bad_request.rawValue:
                print("provider.uploadDidComplete -> bad_request")
            case B2Error.unauthorized.rawValue:
                print("provider.uploadDidComplete -> unauthorized")
            case B2Error.bad_auth_token.rawValue, B2Error.expired_auth_token.rawValue:
                print("provider.uploadDidComplete -> bad_auth_token expired_auth_token")
            case B2Error.cap_exceeded.rawValue:
                print("provider.uploadDidComplete -> cap_exceeded")
            case B2Error.method_not_allowed.rawValue:
                print("provider.uploadDidComplete -> method_not_allowed")
            case B2Error.request_timeout.rawValue:
                print("provider.uploadDidComplete -> request_timeout")
            case B2Error.service_unavailable.rawValue:
                print("provider.uploadDidComplete -> service_unavailable")
            default:
                print("provider.uploadDidComplete -> unhandled")
            }
        }
        
        
    }
    
    //MARK: Private methods
    
    private func startLargeFile(_ asset: PHAsset) {
        guard let fileName = asset.originalFilename else {
            //return Promise(providerError.preparationFailed)
            return
        }
        
        let request = StartLargeFileRequest(bucketId: bucketId,
                                            fileName: fileName,
                                            contentType: HTTPHeaders.contentTypeValue)
        
        var uploadData: Data
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            return
        }
        
        self.fetch(from: Endpoints.startLargeFile, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
            self.recover(from: error, retry: Endpoints.startLargeFile, with: uploadData)
        }.then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            try JSONDecoder().decode(StartLargeFileResponse.self, from: data)
        }.then { parsedResult in
            self.largeFileTest(asset, parsedResult.fileId)
        }.then { fileId, partSha1Array in
            try JSONEncoder().encode(FinishLargeUploadRequest(fileId: fileId, partSha1Array: partSha1Array))
        }.then { uploadData in
            // check queue for another one
            self.fetch(from: Endpoints.finishLargeFile, with: uploadData)
        }
    }
    
    private func uploadFileRequest(from asset: PHAsset, with result: GetUploadURLResponse) -> Promise<(URLRequest?, URL?)> {
        return Promise { fulfill, reject in
            var urlRequest = URLRequest(url: result.uploadUrl)
            
            urlRequest.httpMethod = HTTPMethod.post
            
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
    
    private func recover(from error: Error,retry endpoint: Endpoint,with uploadData: Data) -> Promise<(Data?, URLResponse?)> {
        
        print("bad or expired auth token. attempting refresh then retrying API call.")
        
        switch error {
        case B2Error.bad_auth_token, B2Error.expired_auth_token:
            return self.authorizeAccount().then { data, _ in
                Utility.objectIsType(object: data, someObjectOfType: Data.self)
            }.then { data in
                try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
            }.then { parsedResult in
                self.authorizeAccountResponse = parsedResult
            }.then {
                self.fetch(from: endpoint, with: uploadData) // retry call
            }
        default:
            return Promise(error)
        }
    }

    private func uploadPart(_ result: GetUploadPartURLResponse,_ data: Data,_ url: URL,_ partNumber: Int,_ sha1: String) -> Promise<(Data?, URLResponse?)> {
        var urlRequest = URLRequest(url: result.uploadUrl)
        
        urlRequest.httpMethod = HTTPMethod.post
        
        urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
        urlRequest.setValue(String(partNumber), forHTTPHeaderField: HTTPHeaders.partNumber)
        urlRequest.setValue(String(data.count), forHTTPHeaderField: HTTPHeaders.contentLength)
        urlRequest.setValue(sha1, forHTTPHeaderField: HTTPHeaders.sha1)
        //urlRequest.setValue(data.sha1, forHTTPHeaderField: HTTPHeaders.sha1) // remove this. too many commoncrypto calls

        return fetch(from: urlRequest, with: data)
    }
    
    private func largeFileTest(_ asset: PHAsset, _ fileId: String) -> Promise<(String, [String])>  {
        return Promise { fulfill, _ in
            Utility.getData(from: asset) { _, url in
                let payloadDirURL = URL(fileURLWithPath: NSTemporaryDirectory())
                let payloadFileURL = payloadDirURL.appendingPathComponent(UUID().uuidString)
                
                var partSha1Array = [String]()
                var part = 0
                
                if let inputStream = InputStream.init(url: url),
                    FileManager.default.createFile(atPath: payloadFileURL.path, contents: nil, attributes: nil) {
                    
                    inputStream.open()
                    
                    var buffer = [UInt8](repeating: 0, count: self.recommendedPartSize)
                    var bytes = 0
                    
                    func readBytes() {
                        
                        bytes = inputStream.read(&buffer, maxLength: self.recommendedPartSize)
                        
                        if (bytes > 0 && part < Defaults.maxParts) {
                            part += 1
                            
                            let data = Data(bytes: buffer, count: bytes)
                            partSha1Array.append(data.sha1)
                            //print(partSha1Array.last)
                        
                            do {
                                    let file = try FileHandle(forWritingTo: payloadFileURL)
                                file.write(data)
                                file.truncateFile(atOffset: UInt64(bytes))
                                file.closeFile()
                            } catch {
                                print (error)
                            }
                            
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
                            self.uploadPart(parsedResponse, data, payloadFileURL, part, partSha1Array.last!)
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
            
            if (urlRequest.httpMethod == HTTPMethod.post) {
                URLSession.shared.uploadTask(with: urlRequest, from:uploadData, completionHandler: completionHandler).resume()
            } else if (urlRequest.httpMethod == HTTPMethod.get) {
                URLSession.shared.dataTask(with: urlRequest, completionHandler: completionHandler).resume()
            }
       }
    }
    
    private func fetch(from endpoint: Endpoint, with uploadData: Data? = nil) -> Promise<(Data?, URLResponse?)> {
        guard let url = URL(string: "\(apiUrl)\(endpoint.components.path)") else {
            return Promise(providerError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = endpoint.method
        
        if (authorizationToken == nil) {
            return Promise(B2Error.bad_auth_token)
        } else {
            urlRequest.setValue(authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
        }
        
        return fetch(from: urlRequest,with: uploadData)
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
            let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as? [String: Data]
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
