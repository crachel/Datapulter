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
        static let apiMainURL = "https://api.backblazeb2.com"
        static let authorizeAccountUrl = URL(string: "\(const.apiMainURL)/b2api/v2/b2_authorize_account")
        static let getUploadUrlEndpoint = "/b2api/v2/b2_get_upload_url"
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
    
    var urlPool = CircularBuffer<GetUploadURLResponse?>()
    
    var authorizationToken = UserDefaults.standard.string(forKey: "authorizationToken") ?? "" {
    //var authorizationToken = "badtoken" ?? "" {
        didSet {
            UserDefaults.standard.set(authorizationToken, forKey: "authorizationToken")
        }
    }
    var apiUrl = UserDefaults.standard.string(forKey: "apiUrl") ?? "" {
        didSet {
            UserDefaults.standard.set(apiUrl, forKey: "apiUrl")
        }
    }
    
    var recommendedPartSize = UserDefaults.standard.integer(forKey: "recommendedPartSize") {
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
        // required and must match codes as defined by API
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
    
    
    public func startLargeFile(_ fileName: String) -> Promise<GetUploadPartURLResponse> {
        return Promise {
            self.startLargeFileApi(fileName).recover { error -> Promise<(Data?, URLResponse?)> in
                switch error {
                case B2Error.bad_auth_token, B2Error.expired_auth_token:
                    print("bad or expired auth token. attempting refresh then retrying API call.")
                    return self.authorizeAccount().then { data, _ in
                            //self.parseAuthorizeAccount(data!)
                            try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data!)
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
                    return self.getUploadPartUrlApi(parsedResult["fileId"] as! String)
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
       
        //ignore large files for now
        if (asset.size > const.defaultUploadCutoff ) {
            return Promise(providerError.foundNil)
        }
        
        
        if (urlPool.count > 0) {
            // get url out of the pool
            if let data = urlPool.remove(at: urlPool.headIdx) {
                print("got url out of pool")
                print("url pool count \(urlPool.count)")
                return self.prepareRequest(from: asset, with: data)
                
                //wont check for 401. whole point is to do this with delegates for backgroundsession
            }
        }
        
        return self.getUploadUrlApi().recover { error -> Promise<(Data?, URLResponse?)> in
            switch error {
            case B2Error.bad_auth_token, B2Error.expired_auth_token:
                print("bad or expired auth token. attempting refresh then retrying API call.")
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
        }.catch { error in
            print("(getUrlRequest) unhandled error: \(error.localizedDescription)")
        }
        
    }


    //MARK: Private methods
    
    override func returnUpObj<GetUploadURLResponse>(_ asset: PHAsset,_ uploadObject: GetUploadURLResponse) -> Promise<(UploadObject<GetUploadURLResponse>?)> {
        
        return Promise(UploadObject(asset: asset, urlPoolObject: uploadObject))
    }
    
    public func prepareRequest(from object: UploadObject<GetUploadURLResponse>) -> Promise<(URLRequest?, URL?)> {
        return Promise { fulfill, reject in
            var urlRequest: URLRequest
            urlRequest = URLRequest(url: object.urlPoolObject.uploadUrl)
            urlRequest.httpMethod = HttpMethod.post
            urlRequest.setValue(object.urlPoolObject.authorizationToken, forHTTPHeaderField: const.authorizationHeader)
            urlRequest.setValue(const.contentType, forHTTPHeaderField: const.contentTypeHeader)
            
            urlRequest.setValue(String(object.asset.size), forHTTPHeaderField: const.contentLengthHeader)
            
            if let fileName = object.asset.percentEncodedFilename {
                urlRequest.setValue(fileName, forHTTPHeaderField: const.fileNameHeader)
            } else {
                reject (providerError.foundNil)
            }
            
            if let unixCreationDate = object.asset.creationDate?.millisecondsSince1970  {
                urlRequest.setValue(String(unixCreationDate), forHTTPHeaderField: const.timeHeader)
            } else {
                reject(providerError.foundNil)
            }
            
            Utility.getData(from: object.asset) { data, url in
                urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: const.sha1Header)
                
                fulfill((urlRequest, url))
            }
        }
    }
    
    private func prepareRequest(from asset: PHAsset, with result: GetUploadURLResponse) -> Promise<(URLRequest?, URL?)> {
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

    
    private func fetch(from urlRequest: URLRequest, with uploadData: Data? = nil) -> Promise<(Data?, URLResponse?)> {
        return Promise { fulfill, reject in
            
            let completionHandler: NetworkCompletionHandler = { data, response, error in
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
                            reject (error) // handled status code but problem decoding JSON
                        }
                    } else {
                        reject (providerError.unhandledStatusCode) // unhandled status code
                    }
                } else {
                    reject (providerError.invalidResponse)
                }
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
  
    
    public func getUploadUrlApi() -> Promise<(Data?, URLResponse?)> {
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
    
    private func parseGetUploadPartUrl(_ data: Data) throws -> Promise<GetUploadPartURLResponse?> {
        return Promise { () -> GetUploadPartURLResponse in
            do {
                self.getUploadPartUrlResponse = try JSONDecoder().decode(GetUploadPartURLResponse.self, from: data)
                if let response = self.getUploadPartUrlResponse {
                    return response
                } else {
                    throw providerError.optionalBinding
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
            return Promise(providerError.preparationFailed)
        }
        
        urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HttpMethod.post
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: const.authorizationHeader)
        
        return fetch(from: urlRequest,with: uploadData)
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
