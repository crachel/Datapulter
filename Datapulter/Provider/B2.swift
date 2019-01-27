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
        static let headerPrefix = "x-bz-info-"
        static let timeKey = "src_last_modified_millis"
        static let timeHeader = headerPrefix + timeKey
        static let sha1Key = "large_file_sha1"
        static let sha1Header = "X-Bz-Content-Sha1"
        static let sha1InfoHeader = headerPrefix + sha1Key
        static let testModeHeader = "X-Bz-Test-Mode"
        static let retryAfterHeader = "Retry-After"
        static let maxParts = 10000
        static let maxVersions = 100 // maximum number of versions we search in --b2-versions mode
        static let defaultUploadCutoff = 200 * 1024 * 1024
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
   
    
    //MARK: API Responses
    
    
    var authorizeAccountResponse: AuthorizeAccountResponse? {
        didSet {
            authorizationToken = authorizeAccountResponse!.authorizationToken
            apiUrl = authorizeAccountResponse!.apiUrl
        }
    }
    var listBucketsResponse: ListBucketsResponse?
    var getUploadUrlResponse: GetUploadURLResponse?
    
    
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
    

    public func listBuckets(_ attempts: Int = 1) {
        if (attempts > 5) { return } // avoid infinite loop
        
        listBuckets().then { data, response in
            try self.parseListBuckets(data!)
        }.then { parsedResult in
            print(parsedResult!)
        }.recover { error -> Void in
            switch error {
            case B2Error.bad_auth_token, B2Error.expired_auth_token:
                print("it's bad_auth_token again")
            default:
                print("unhandled error: \(error)")
            }
        }.catch { error in
            print("unhandled error: \(error)")
        }
    }
    
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
                        print("unhandled error: \(error)")
                    }
                default:
                    print("unhandled error: \(error)")
                    return Promise(error)
                }
            }.then { data, _ in
                try self.parseGetUploadUrl(data!) // force unwrap should be safe
            }.then { parsedResult in
                return parsedResult // successful chain ends here
            }.catch { error in
                print("unhandled error: \(error)")
            }
        }
    }
    
    public func startUploadTask() {
        if (!assetsToUpload.isEmpty) {
            getUploadUrl().then { result in
                var urlRequest: URLRequest
                let assetResources = PHAssetResource.assetResources(for: self.assetsToUpload.first!)
                
                urlRequest = URLRequest(url: result.uploadUrl)
                urlRequest.httpMethod = "POST"
                urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: "Authorization")
                urlRequest.setValue(String(Utility.getSizeFromAsset(self.assetsToUpload.first!)), forHTTPHeaderField: "Content-Length")
                urlRequest.setValue("b2/x-auto", forHTTPHeaderField: "Content-Type")
                urlRequest.setValue(assetResources.first!.originalFilename.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed), forHTTPHeaderField: "X-Bz-File-Name")
                urlRequest.setValue(String(self.assetsToUpload.first!.creationDate!.millisecondsSince1970), forHTTPHeaderField: "X-Bz-Info-src_last_modified_millis")
                
                autoreleasepool(invoking: { () -> () in
                    Utility.getDataFromAsset(self.assetsToUpload.first!) { data in
                        
                        urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: "X-Bz-Content-Sha1")
                        
                        Utility.getUrlFromAsset(self.assetsToUpload.first!) { url in
                            let taskId = Client.shared.upload(urlRequest, url!)
                            AutoUpload.shared.uploadingAssets = [taskId: self.assetsToUpload.first!]
                        }
                        
                    }
                })
                
                print(result.uploadUrl)
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
                return try JSONDecoder().decode(GetUploadURLResponse.self, from: data)
            } catch {
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
