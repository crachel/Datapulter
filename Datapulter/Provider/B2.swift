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
    
    struct const {
        static let server = "https://www.backblaze.com/"
        static let apiMainURL = "https://api.backblazeb2.com"
        static let authorizeAccountUrl = URL(string: "\(const.apiMainURL)/b2api/v2/b2_authorize_account")
        static let getUploadUrlEndpoint = "/b2api/v2/b2_get_upload_url"
        static let startLargeFileEndpoint = "/b2api/v2/b2_start_large_file"
        static let finishLargeFileEndpoint = "/b2api/v2/b2_finish_large_file"
        static let headerPrefix = "X-Bz-Info-"
        static let authorizationHeader = "Authorization"
        static let fileNameHeader = "X-Bz-File-Name"
        static let contentLengthHeader = "Content-Length"
        static let contentType = "b2/x-auto"
        static let contentTypeHeader = "Content-Type"
        static let timeKey = "src_last_modified_millis"
        static let timeHeader = headerPrefix + timeKey
        static let sha1Key = "large_file_sha1"
        static let sha1Header = "X-Bz-Content-Sha1"
        static let sha1InfoHeader = headerPrefix + sha1Key
        static let testModeHeader = "X-Bz-Test-Mode"
        static let retryAfterHeader = "Retry-After"
        static let mimeType = "application/json"
        static let maxParts = 10000
        static let maxVersions = 100 // maximum number of versions we search in --b2-versions mode
        static let defaultUploadCutoff = 200 * 1_000 * 1_000
        static let defaultChunkSize = 100 * 1_000 * 1_000
    }
    
    var account: String
    var key: String
    var bucket: String
    var accountId: String
    var bucketId: String
    var versions: Bool
    var harddelete: Bool
    var dispatchQueue = DispatchQueue(label: "thread-safe-circularbuffer", attributes: .concurrent)
    var urlPool = CircularBuffer<GetUploadURLResponse?>()
    
    var authorizationToken: String {
        get {
            if let result = KeychainHelper.get(account: account),
                let tokenData = result[kSecValueData as String] as? Data,
                let token = String(data: tokenData, encoding: .utf8) {
                return token
            }
            
            return ""
        }
    }
    
    var apiUrl: String {
        get {
            if let result = KeychainHelper.get(account: account),
                let url = result[kSecAttrServer as String] as? String {
                return url
            }
            
            return const.apiMainURL // keeps urlsessiontask from failing
        }
    }
    
    var recommendedPartSize: Int {
        get {
            return UserDefaults.standard.integer(forKey: PropertyKey.recommendedPartSize)
        }
    }
   
    
    //MARK: API Responses
    
    
    var authorizeAccountResponse: AuthorizeAccountResponse? {
        didSet {
            UserDefaults.standard.set(authorizeAccountResponse!.recommendedPartSize, forKey: PropertyKey.recommendedPartSize)
            if(KeychainHelper.update(account: account, value: authorizeAccountResponse!.authorizationToken, server: authorizeAccountResponse!.apiUrl)) {
                print("B2.authorizationToken saved to keychain")
            } else {
                // keychain save problem
            }
        }
    }
    var listBucketsResponse: ListBucketsResponse?
    var getUploadUrlResponse: GetUploadURLResponse?
    var getUploadPartUrlResponse: GetUploadPartURLResponse?
    
    
    //MARK: Types
    
    
    enum B2Error: String, Error {
        // required. must match codes as defined by API
        case bad_request // 400
        case unauthorized // 401
        case bad_auth_token // 401
        case expired_auth_token // 401
        case service_unavailable // 503
        
        case unmatchedError
    }
    
    struct PropertyKey {
        static let account = "account"
        static let key = "key"
        static let bucket = "bucket"
        static let versions = "versions"
        static let harddelete = "harddelete"
        static let uploadList = "uploadList"
        static let accountId = "accountId"
        static let bucketId = "bucketId"
        
        static let authorizationToken = "authorizationToken"
        static let apiUrl = "apiUrl"
        static let recommendedPartSize = "recommendedPartSize"
    }
    
    
    //MARK: Initialization
    
    
    init(name: String, account: String, key: String, bucket: String, versions: Bool, harddelete: Bool, accountId: String, bucketId: String) {
    // init for when user adds new provider
        self.account = account
        self.key = key
        self.bucket = bucket
        self.versions = versions
        self.harddelete = harddelete
        self.accountId = accountId
        self.bucketId = bucketId
        
        super.init(name: name, backend: .Backblaze)
    }
    
    
    //MARK: Public methods
    
    
    override func getUrlRequest(_ asset: PHAsset) -> Promise<(URLRequest?, URL?)> {
        
        if (asset.size > const.defaultUploadCutoff ) {
            startLargeFile(asset)
            return Promise(providerError.foundNil) //need to return here so we don't try to process large file anyway
        }// else {
         //   return Promise(providerError.foundNil)
        //}
        
        /*
        let dispatchQueue = DispatchQueue(label: "com.example.Datapulter.background")
        
        //var count = 0
        /*
        dispatchQueue.sync {
            count = urlPool.count
        }*/
        
        let count = dispatchQueue.sync {
            return urlPool.count
        }
        
        if (count > 0) {
            // get url out of the pool
            
            let data = dispatchQueue.sync {
                return urlPool.remove(at: urlPool.headIdx)
            }
            
            
            print("got url out of pool")
            print("url pool count \(urlPool.count)")
            return self.prepareRequest(from: asset, with: data!)
            
            //wont check for 401. whole point is to do this with delegates for backgroundsession
            
            /*
            if let data = urlPool.remove(at: urlPool.headIdx) {
                print("got url out of pool")
                print("url pool count \(urlPool.count)")
                return self.prepareRequest(from: asset, with: data)
                
                //wont check for 401. whole point is to do this with delegates for backgroundsession
            }*/
            
       }*/
        
        return self.getUploadUrlApi().recover { error -> Promise<(Data?, URLResponse?)> in
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
                    self.getUploadUrlApi() // succesfully authorized now retry call
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

    override func login() -> Promise<Bool> {
        return Promise { fulfill, reject in
            self.authorizeAccount().then { data, response in
                if let response = response as? HTTPURLResponse,
                    response.statusCode == 200 {
                    fulfill(true)
                } else {
                    fulfill(false)
                }
            }
        }
    }
    //MARK: Private methods
    
    
    private func prepareRequest(from asset: PHAsset, with result: GetUploadURLResponse) -> Promise<(URLRequest?, URL?)> {

        
        let (count, capacity) = dispatchQueue.sync {
            return (urlPool.count, urlPool.capacity)
        }
        
        // add to urlPool, if there's room
        dispatchQueue.async(flags: .barrier) {
            if (count < (capacity - 1)) {
                self.urlPool.append(result)
            }
        }
        
        return Promise { fulfill, reject in
            var urlRequest: URLRequest
            urlRequest = URLRequest(url: result.uploadUrl)
            urlRequest.httpMethod = HttpMethod.post
            urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: const.authorizationHeader)
            urlRequest.setValue(const.contentType, forHTTPHeaderField: const.contentTypeHeader)
            
            urlRequest.setValue(String(asset.size), forHTTPHeaderField: const.contentLengthHeader)
            
            if let fileName = asset.percentEncodedFilename {
                urlRequest.setValue(fileName, forHTTPHeaderField: const.fileNameHeader)
            } else {
                reject (providerError.foundNil)
            }
            
            if let unixCreationDate = asset.creationDate?.millisecondsSince1970  {
                urlRequest.setValue(String(unixCreationDate), forHTTPHeaderField: const.timeHeader)
            } else {
                reject(providerError.foundNil)
            }
            
            Utility.getData(from: asset) { data, url in
                urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: const.sha1Header)
            
                fulfill((urlRequest, url))
            }
        }
    }
    

    private func startLargeFile(_ asset: PHAsset) -> Promise<(Data?, URLResponse?)> {
        guard let fileName = asset.originalFilename else {
            
            return Promise(providerError.preparationFailed)
        }
        
        //var fileId: String?
    
        return self.startLargeFileApi(fileName).recover { error -> Promise<(Data?, URLResponse?)> in
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
                    self.startLargeFileApi(fileName) // retry call
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
            self.finishLargeFile(fileId, partSha1Array)
        }
    }
    
    private func uploadPart(_ result: GetUploadPartURLResponse,_ data: Data,_ url: URL,_ partNumber: Int) -> Promise<(Data?, URLResponse?)> {
        var urlRequest: URLRequest
        urlRequest = URLRequest(url: result.uploadUrl)
        urlRequest.httpMethod = HttpMethod.post
        urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        urlRequest.setValue(String(partNumber), forHTTPHeaderField: "X-Bz-Part-Number")
        
        urlRequest.setValue(String(data.count), forHTTPHeaderField: const.contentLengthHeader)
        
        urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: const.sha1Header)
        
        return fetch(from: urlRequest, with: data)
    }
    
    private func finishLargeFile(_ fileId: String,_ partSha1Array: [String]) -> Promise<(Data?, URLResponse?)> {
        var urlRequest: URLRequest
        var uploadData: Data
        
        let request = FinishLargeUploadRequest(fileId: fileId,
                                               partSha1Array: partSha1Array)
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            return Promise(error)
        }
        
        guard let url = URL(string: "\(apiUrl)\(const.finishLargeFileEndpoint)") else {
            return Promise(providerError.preparationFailed)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post
        
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest, with: uploadData)
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
                            
                            if bytes > 0 {
                                part += 1
                                let data = Data(bytes: buffer, count: bytes)
                                partSha1Array.append(data.hashWithRSA2048Asn1Header(.sha1)!)
                                let written = outputStream.write(buffer, maxLength: bytes)
                                
                                print("bytes written to outputStream: \(written)")
                                preparePart(data).then { _, _ in
                                    readBytes()
                                }
                            } else {
                                do {
                                    print("trying to remove payloadFileURL...", terminator:"")
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
                        return self.getUploadPartUrlApi(fileId).then { data, response in
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
                    mimeType == const.mimeType,
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
    
    private func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        guard let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString() else {
            return Promise(providerError.preparationFailed)
        }
        
        guard let url = const.authorizeAccountUrl else {
            return Promise(providerError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.get
        urlRequest.setValue("Basic \(authNData)", forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest)
    }
  
    
    private func getUploadUrlApi() -> Promise<(Data?, URLResponse?)> {
        var urlRequest: URLRequest
        var uploadData: Data
        
        let request = GetUploadURLRequest(bucketId: bucketId)
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            return Promise(error)
        }
        
        guard let url = URL(string: "\(apiUrl)\(const.getUploadUrlEndpoint)") else {
            return Promise(providerError.preparationFailed)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post
        
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest, with: uploadData)
    }
    
   
    private func getUploadPartUrlApi(_ fileId: String) -> Promise<(Data?, URLResponse?)> {
        var urlRequest: URLRequest
        var uploadData: Data
        
        let request = GetUploadPartURLRequest(fileId: fileId)
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            return Promise(error)
        }
        
        guard let url = URL(string: "\(apiUrl)/b2api/v2/b2_get_upload_part_url") else {
            return Promise(providerError.preparationFailed)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest, with: uploadData)
    }

    private func startLargeFileApi(_ fileName: String) -> Promise<(Data?, URLResponse?)> {
        var urlRequest: URLRequest
        var uploadData: Data
        
        let request = StartLargeFileRequest(bucketId: bucketId,
                                            fileName: fileName,
                                            contentType: const.contentType)
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            return Promise(error)
        }
        
        //guard let url = URL(string: "\(apiUrl)/b2api/v2/b2_start_large_file") else {
        guard let url = URL(string: "\(apiUrl)\(const.startLargeFileEndpoint)") else {
            return Promise(providerError.preparationFailed)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest,with: uploadData)
    }

    private func listBuckets() -> Promise<(Data?, URLResponse?)> {
        
        let request = ListBucketsRequest(accountId: self.accountId,
                                         bucketName: self.bucket)
        
        let uploadData = try? JSONEncoder().encode(request)

        let url = URL(string: "\(apiUrl)/b2api/v2/b2_list_buckets")
        
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = HttpMethod.post
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest,with: uploadData!)
    }
    
    private func parseListBuckets(_ data: Data) throws -> Promise<ListBucketsResponse?> {
        return Promise { () -> ListBucketsResponse in
            do {
                return try JSONDecoder().decode(ListBucketsResponse.self, from: data)
            } catch {
                throw (error)
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
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // These are required. If we cannot decode, the initializer should fail.
        guard
            let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String,
            let account = aDecoder.decodeObject(forKey: PropertyKey.account) as? String,
            let key = aDecoder.decodeObject(forKey: PropertyKey.key) as? String,
            let bucket = aDecoder.decodeObject(forKey: PropertyKey.bucket) as? String,
            let accountId = aDecoder.decodeObject(forKey: PropertyKey.accountId) as? String,
            let bucketId = aDecoder.decodeObject(forKey: PropertyKey.bucketId) as? String
        else
        {
            os_log("Unable to decode a B2 object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let versions = aDecoder.decodeBool(forKey: PropertyKey.versions)
        let harddelete = aDecoder.decodeBool(forKey: PropertyKey.harddelete)
        
        
        // Must call designated initializer.
        self.init(name: name, account: account, key: key, bucket: bucket, versions: versions, harddelete: harddelete, accountId: accountId, bucketId: bucketId)
    }
 
}
