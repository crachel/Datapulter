//
//  B2.swift
//
//
//  Created by Craig Rachel on 12/5/18.
//

import UIKit
import os.log
import Promises


class B2: Provider {
    
    
    //MARK: Properties
    
    /*
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        //return URLSession(configuration: configuration,delegate: self, delegateQueue: nil)
        return URLSession(configuration: configuration)
    }()*/
    
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
    var authorizationToken: String = "4_000bd9db9a329de0000000002_01899d11_2de77d_acct_1zmYZinB8pkycmYx6I3bqJe3zt0="
    
    var versions: Bool
    var harddelete: Bool
    
    
    //MARK: API Responses
    
    
    var authorizeAccountResponse: AuthorizeAccountResponse? {
        didSet {
            print("authorization set")
        }
    }
    var listBucketsResponse: ListBucketsResponse?
    var getUploadUrlResponse: GetUploadURLResponse?
    
    
    //MARK: Types
    
    
    enum B2Error: String, Error {
        case none
        case downcast
        case bad_request // 400
        case unauthorized // 401
        case bad_auth_token // 401
        case expired_auth_token // 401
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
    

    public func login() {
        authorizeAccount().then { data, response in
            self.authorizeAccountResponse = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data!)
        }.catch { error in
            print("Encountered error: \(error)")
        }
    }
    
    
    public func listBuckets() {
     listBuckets().then { data, response in
        return self.parseListBuckets(data!)
     }.then { parsedResult in
        print(parsedResult!)
     }.recover { error -> Void in
         switch error {
            case B2Error.bad_auth_token, B2Error.expired_auth_token:
         print("it's bad_auth_token again")
            default:
         print("something else")
     }
     //print("error in recover: \(error)")
     }.catch { error in
        print("should be here if error in request")
     }
    }
    
    public func getUploadUrl() {
        getUploadUrl().then { data, response in
            return self.parseGetUploadUrl(data!)
        }.then { parsedResult in
            print(parsedResult!)
        }.recover { error -> Void in
            switch error {
            case B2Error.bad_auth_token, B2Error.expired_auth_token:
                print("it's bad_auth_token again")
            default:
                print("something else")
            }
            //print("error in recover: \(error)")
        }.catch { error in
            print("should be here if error in request")
        }
    }
    
    public func createAuthToken() {

        var urlRequest = URLRequest(url: const.authorizeAccountUrl!)
        urlRequest.httpMethod = "GET"
        
        let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString()
        
        urlRequest.setValue("Basic \(authNData!)", forHTTPHeaderField: "Authorization")
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let error = error {
                print ("error: \(error)")
                return
            }
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                    print ("server error")
                    return
            }
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data {
                
                self.authorizeAccountResponse = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
                print(self.authorizeAccountResponse!)
            }
        }
        task.resume()
    }
    
    
    //MARK: Private methods
    
    
    private func get(_ urlrequest: URLRequest) -> Promise<(Data?, URLResponse?)> {
        return wrap { URLSession.shared.dataTask(with: urlrequest, completionHandler: $0).resume() }
    }
    
    private func post(_ urlRequest: URLRequest,_ uploadData: Data) -> Promise<(Data?, URLResponse?)> {
        return Promise { fulfill, reject in
            
            let dataTask = URLSession.shared.uploadTask(with: urlRequest, from:uploadData) { data, response, error in
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
                        let jsonerror = try! JSONDecoder().decode(JSONError.self, from: data)
                        
                        reject (B2Error(rawValue: jsonerror.code) ?? B2Error.unknown)
                    } else {
                        reject (B2Error.unknown) // unhandled status code
                    }
                }
            }
            dataTask.resume()
        }
    }
    
    private func parseGetUploadUrl(_ data: Data) -> Promise<GetUploadURLResponse?> {
        return Promise { () -> GetUploadURLResponse in
            let response = try! JSONDecoder().decode(GetUploadURLResponse.self, from: data)
            
            return response
        }
    }
    
    private func getUploadUrl() -> Promise<(Data?, URLResponse?)> {
        
        let request = GetUploadURLRequest(bucketId: bucketId)
        let uploadData = try? JSONEncoder().encode(request)
        
        let url = URL(string: "https://api000.backblazeb2.com/b2api/v2/b2_get_upload_url")
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(self.authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData!)
    }

    private func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString()
        
        var urlRequest = URLRequest(url: const.authorizeAccountUrl!)
        urlRequest.httpMethod = "GET"
        urlRequest.setValue("Basic \(authNData!)", forHTTPHeaderField: "Authorization")
        
        return get(urlRequest)
    }

    private func listBuckets() -> Promise<(Data?, URLResponse?)> {
        
        let request = ListBucketsRequest(accountId: self.accountId,
                                         bucketName: self.bucket)
        
        let uploadData = try? JSONEncoder().encode(request)

        let url = URL(string: "https://api000.backblazeb2.com/b2api/v2/b2_list_buckets")
        
        var urlRequest = URLRequest(url: url!)
       
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(self.authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData!)
    }
    
    private func parseListBuckets(_ data: Data) -> Promise<ListBucketsResponse?> {
        return Promise { () -> ListBucketsResponse in
            let response = try! JSONDecoder().decode(ListBucketsResponse.self, from: data)
            
            return response
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
