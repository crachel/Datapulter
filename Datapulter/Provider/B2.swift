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

    
    struct const {
        static let apiMainURL = "https://api.backblazeb2.com"
        static let authorizeAccountUrl = URL(string: "\(const.apiMainURL)/b2api/v2/b2_authorize_account")
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
        static let maxParts = 10000
        static let maxVersions = 100 // maximum number of versions we search in --b2-versions mode
        static let defaultUploadCutoff = 200 * 1_024 * 1_024
        static let defaultChunkSize = 96 * 1_024 * 1_024
    }
    
    var account: String
    var key: String
    var bucket: String
    var accountId: String
    var bucketId: String
    var versions: Bool
    var harddelete: Bool
    
    var authorizationToken = UserDefaults.standard.string(forKey: "authorizationToken") ?? "" {
        didSet {
            UserDefaults.standard.set(authorizationToken, forKey: "authorizationToken")
        }
    }
    var apiUrl = UserDefaults.standard.string(forKey: "apiUrl") ?? "" {
        didSet {
            UserDefaults.standard.set(apiUrl, forKey: "apiUrl")
        }
    }
    
    var recommendedPartSize = UserDefaults.standard.integer(forKey: "recommendedPartSize"){
        didSet {
            UserDefaults.standard.set(recommendedPartSize, forKey: "recommendedPartSize")
        }
    }
   
    
    //MARK: API Responses
    
    
    var authorizeAccountResponse: AuthorizeAccountResponse? {
        didSet {
            authorizationToken = authorizeAccountResponse!.authorizationToken
            apiUrl = authorizeAccountResponse!.apiUrl
            recommendedPartSize = authorizeAccountResponse!.recommendedPartSize
        }
    }
    var listBucketsResponse: ListBucketsResponse?
    var getUploadUrlResponse: GetUploadURLResponse?
    var getUploadPartUrlResponse: GetUploadPartURLResponse?
    
    
    //MARK: Types
    
    
    enum B2Error: String, Error {
        case none
        case downcast
        case connectionError
        case bad_request // 400
        case unauthorized // 401
        case bad_auth_token // 401
        case expired_auth_token // 401
        case service_unavailable // 503
        case invalidResponse
        case serverError
        case unknown
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
    
    
    public func getUploadUrl() -> Promise<GetUploadURLResponse> {
        return Promise {
            self.getUploadUrlApi().recover { error -> Promise<(Data?, URLResponse?)> in
                switch error {
                case B2Error.bad_auth_token, B2Error.expired_auth_token:
                    print("bad or expired auth token. attempting refresh then retrying API call.")
                    return self.authorizeAccount().then { data, _ in
                        try self.parseAuthorizeAccount(data!)
                    }.then { parsedResult in
                        self.authorizeAccountResponse = parsedResult
                    }.then {
                        self.getUploadUrlApi() // retry call
                    }.catch { error in
                        print("unhandled error (authorizeAccount): \(error)")
                    }
                default:
                    print("unhandled error (getUploadUrlApi): \(error)")
                    return Promise(error)
                }
            }.then { data, _ in
                try self.parseGetUploadUrl(data!) // force unwrap should be safe
            }.then { parsedResult in
                return parsedResult // successful chain ends here
            }.catch { error in
                print("unhandled error (getUploadUrlApi): \(error)")
            }
        }
    }
    
    public func startLargeFile(_ fileName: String) -> Promise<GetUploadPartURLResponse> {
        return Promise {
            self.startLargeFileApi(fileName).recover { error -> Promise<(Data?, URLResponse?)> in
                switch error {
                case B2Error.bad_auth_token, B2Error.expired_auth_token:
                    print("bad or expired auth token. attempting refresh then retrying API call.")
                    return self.authorizeAccount().then { data, _ in
                        try self.parseAuthorizeAccount(data!)
                        }.then { parsedResult in
                            self.authorizeAccountResponse = parsedResult
                        }.then {
                            self.startLargeFileApi(fileName) // retry call
                        }.catch { error in
                            print("unhandled error (authorizeAccount): \(error)")
                    }
                default:
                    print("unhandled error (startLargeFileApi): \(error.localizedDescription)")
                    return Promise(error)
                }
                }.then { data, _ in
                    try self.parseStartLargeFile(data!) // force unwrap should be safe
                }.then { parsedResult in
                    return self.getUploadPartUrlApi(parsedResult["fileId"] as! String) // successful chain ends here
                }.then { data, _ in
                    try self.parseGetUploadPartUrl(data!) // force unwrap should be safe
                }.then { parsedResult in
                    return parsedResult // successful chain ends here
                }.catch { error in
                    print("unhandled error (startLargeFile): \(error)")
            }
        }
    }
    
    override func getUrlRequest(_ asset: PHAsset) -> Promise<(URLRequest?, URL?)> {
        return Promise { fulfill, reject in
                    
            let size = Utility.getSizeFromAsset(asset)
            
            if (size < const.defaultUploadCutoff ) {
                self.getUploadUrl().then { result in
                    var urlRequest: URLRequest
                    urlRequest = URLRequest(url: result.uploadUrl)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: const.authorizationHeader)
                    urlRequest.setValue(const.contentType, forHTTPHeaderField: const.contentTypeHeader)
                    
                    urlRequest.setValue(String(size), forHTTPHeaderField: const.contentLengthHeader)
                    
                    if let assetResources = PHAssetResource.assetResources(for: asset).first {
                        if let fileName = assetResources.originalFilename.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                            urlRequest.setValue(fileName, forHTTPHeaderField: const.fileNameHeader)
                        } else {
                            reject (providerError.optionalBinding)
                        }
                    } else {
                        reject (providerError.optionalBinding)
                    }
                    
                    if let unixCreationDate = asset.creationDate?.millisecondsSince1970  {
                        urlRequest.setValue(String(unixCreationDate), forHTTPHeaderField: const.timeHeader)
                    } else {
                        reject(providerError.optionalBinding)
                    }
                    
                    Utility.getDataFromAsset(asset) { data in
                        urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: const.sha1Header)
                        
                        
                        Utility.getUrlFromAsset(asset) { url in
                            if let url = url {
                                fulfill((urlRequest, url))
                            } else {
                                reject(providerError.optionalBinding)
                            }
                        }
                    }
                }
            } // else handle large upload
        }
    }
    
    public func startUploadTask() {
        if (!assetsToUpload.isEmpty) {
            if let asset = self.assetsToUpload.first {
                
                let size = Utility.getSizeFromAsset(asset) // < const.defaultUploadCutoff
                
                if (size < const.defaultUploadCutoff ) {
                    getUploadUrl().then { result in
                        var urlRequest: URLRequest
                        
                        urlRequest = URLRequest(url: result.uploadUrl)
                        urlRequest.httpMethod = "POST"
                        urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: const.authorizationHeader)
                        urlRequest.setValue(const.contentType, forHTTPHeaderField: const.contentTypeHeader)
                        
                        urlRequest.setValue(String(size), forHTTPHeaderField: const.contentLengthHeader)
                        
                        if let assetResources = PHAssetResource.assetResources(for: asset).first {
                            if let fileName = assetResources.originalFilename.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                                urlRequest.setValue(fileName, forHTTPHeaderField: const.fileNameHeader)
                                
                            }
                        }
                        
                        if let unixCreationDate = asset.creationDate?.millisecondsSince1970  {
                            urlRequest.setValue(String(unixCreationDate), forHTTPHeaderField: const.timeHeader)
                        }
                        
                        Utility.getDataFromAsset(asset) { data in
                            urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: const.sha1Header)
                            
                            Utility.getUrlFromAsset(asset) { url in
                                if let url = url {
                                    let taskId = Client.shared.upload(urlRequest, url)
                                    AutoUpload.shared.uploadingAssets = [taskId: asset]
                                }
                            }
                        }
                    }
                } else {
                    // handle large upload
                    let payloadFileURL = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent(UUID().uuidString)
                    
                    //open temp dir for writing from stream. means user needs const.defaultchunksize
                    //available space. could be problem. need to check for this eventually
                    guard let outputStream = OutputStream(url: payloadFileURL, append: false) else {
                        return
                    }
                    
                    Utility.getUrlFromAsset(asset) { url in
                        if let url = url {
                            if let inputStream = InputStream.init(url: url) {
                                inputStream.open()
                                var buffer = [UInt8](repeating: 0, count: self.recommendedPartSize)
                                var bytes = 0
                                var totalBytes = 0
                                repeat {
                                    bytes = inputStream.read(&buffer, maxLength: self.recommendedPartSize)
                                    if bytes > 0 {
                                        let data = Data(bytes: buffer, count: bytes)
                                        
                                        print("sha1 \(String(describing: data.hashWithRSA2048Asn1Header(.sha1)))")
                                        print("data.count \(data.count)")
                                        print("bytes \(String(bytes))")
                                        
                                        // write to temp file
                                        outputStream.write(buffer, maxLength: bytes)
                                        
                                        if let assetResources = PHAssetResource.assetResources(for: asset).first {
                                            if let fileName = assetResources.originalFilename.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) {
                                                //urlRequest.setValue(fileName, forHTTPHeaderField: const.fileNameHeader)
                                                self.startLargeFile(fileName).then { result in
                                                    print(result.uploadUrl)
                                                }
                                            }
                                        }
                                        do {
                                            try FileManager.default.removeItem(at: payloadFileURL)
                                        } catch {
                                            
                                        }
                                        
                                        totalBytes += bytes
                                    }
                                } while bytes > 0
                                
                                inputStream.close()
                            }
                        }
                    }
                }
            }
        }
    }


    //MARK: Private methods
    
    
    private func get(_ urlrequest: URLRequest) -> Promise<(Data?, URLResponse?)> {
        return wrap { URLSession.shared.dataTask(with: urlrequest, completionHandler: $0).resume() }
    }
    
    private func post(_ urlRequest: URLRequest,_ uploadData: Data) -> Promise<(Data?, URLResponse?)> {
        return Promise { fulfill, reject in
            
            let uploadTask = URLSession.shared.uploadTask(with: urlRequest, from:uploadData) { data, response, error in
                if let error = error {
                    print ("error: \(error)")
                    reject(error)
                }
                
                guard let response = response as? HTTPURLResponse else { return }
                
                if let mimeType = response.mimeType,
                    mimeType == "application/json",
                    let data = data {
                    
                    if (response.statusCode == 200) {
                        fulfill((data, response))
                    } else if (400...401).contains(response.statusCode) {
                        do {
                            let jsonerror = try JSONDecoder().decode(JSONError.self, from: data)
                            reject (B2Error(rawValue: jsonerror.code) ?? B2Error.invalidResponse) // handled status code
                        } catch {
                            reject (error) // handled status code but problem decoding JSON
                        }
                    } else {
                        reject (B2Error.invalidResponse) // unhandled status code
                    }
                }
            }
            uploadTask.resume()
        }
    }
    
    private func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString()
        
        var urlRequest = URLRequest(url: const.authorizeAccountUrl!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Basic \(authNData!)", forHTTPHeaderField: "Authorization")
        
        return get(urlRequest)
    }
    
    private func parseAuthorizeAccount(_ data: Data) throws -> Promise<AuthorizeAccountResponse> {
        return Promise { () -> AuthorizeAccountResponse in
            do {
                return try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
            } catch {
                throw error
            }
        }
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
            return Promise(B2Error.unknown)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData)
    }
    
    private func parseGetUploadPartUrl(_ data: Data) throws -> Promise<GetUploadPartURLResponse?> {
        return Promise { () -> GetUploadPartURLResponse in
            do {
                self.getUploadPartUrlResponse = try JSONDecoder().decode(GetUploadPartURLResponse.self, from: data)
                if let response = self.getUploadPartUrlResponse {
                    return response
                } else {
                    throw B2Error.unknown
                }
            } catch {
                throw error
            }
        }
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
        
        guard let url = URL(string: "\(apiUrl)/b2api/v2/b2_get_upload_url") else {
            return Promise(B2Error.unknown)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData)
    }
    
    private func parseGetUploadUrl(_ data: Data) throws -> Promise<GetUploadURLResponse?> {
        return Promise { () -> GetUploadURLResponse in
            do {
                self.getUploadUrlResponse = try JSONDecoder().decode(GetUploadURLResponse.self, from: data)
                if let response = self.getUploadUrlResponse {
                    return response
                } else {
                    throw B2Error.unknown
                }
            } catch {
                throw error
            }
        }
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
        
        guard let url = URL(string: "\(apiUrl)/b2api/v2/b2_start_large_file") else {
            return Promise(B2Error.unknown)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData)
    }
    
    private func parseStartLargeFile(_ data: Data) throws -> Promise<[String?: Any?]> {
        return Promise { () -> [String: Any] in
            do {
                let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                return json
            } catch {
                print("\(error.localizedDescription)")
                throw error
            }
        }
    }

    private func listBuckets() -> Promise<(Data?, URLResponse?)> {
        
        let request = ListBucketsRequest(accountId: self.accountId,
                                         bucketName: self.bucket)
        
        let uploadData = try? JSONEncoder().encode(request)

        let url = URL(string: "\(apiUrl)/b2api/v2/b2_list_buckets")
        
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData!)
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
