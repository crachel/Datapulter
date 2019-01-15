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
    
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        //return URLSession(configuration: configuration,delegate: self, delegateQueue: nil)
        return URLSession(configuration: configuration)
    }()
    
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
    var versions: Bool
    var harddelete: Bool
    var authorization: AuthorizeAccountResponse? {
        didSet {
            print("authorization set")
        }
    }
    var buckets: ListBucketsResponse?
    var uploadurl: GetUploadURLResponse?
    
    enum CustomError: Error {
        case none
        case code(Int)
        /*case bad_request // 400
        case unauthorized // 401
        case bad_auth_token // 401
        case expired_auth_token // 401
 */
    }
    
    
    //MARK: Types
    
    
    struct PropertyKey {
        static let account = "account"
        static let key = "key"
        static let bucket = "bucket"
        static let versions = "versions"
        static let harddelete = "harddelete"
        static let uploadList = "uploadList"
    }
    
    
    //MARK: Initialization
    
    
    init(name: String, account: String, key: String, bucket: String, versions: Bool, harddelete: Bool) {
    // init for when user adds new provider
        self.account = account
        self.key = key
        self.bucket = bucket
        self.versions = versions
        self.harddelete = harddelete
        
        super.init(name: name, backend: .Backblaze)
    }
    
    
    //MARK: Public methods
    

    public func login() {
        authorize_account().then { data, response in
            self.authorization = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data!)
        }.catch { error in
            print("Encountered error: \(error)")
        }
    }
    
    public func login2() {
        authorize_account().then { data, response in
            return self.testbuckets(data!)
        }.then { data, response in
            self.buckets = try! JSONDecoder().decode(ListBucketsResponse.self, from: data!)
        }.catch { error in
            print("Encountered error: \(error)")
        }
    }
    
    
    public func createAuthToken() {

        var urlRequest = URLRequest(url: const.authorizeAccountUrl!)
        urlRequest.httpMethod = "GET"
        
        let task = session.dataTask(with: urlRequest) { data, response, error in
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
                
                self.authorization = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
            }
        }
        task.resume()
    }
    
    
    //MARK: Private methods
    
    
    private func get(_ urlrequest: URLRequest) -> Promise<(Data?, URLResponse?)> {
        return wrap { self.session.dataTask(with: urlrequest, completionHandler: $0).resume() }
    }
    
    private func post(_ urlrequest: URLRequest,_ data: Data) -> Promise<(Data?, URLResponse?)> {
        return wrap { self.session.uploadTask(with: urlrequest, from: data, completionHandler: $0).resume() }
    }
    
    private func post2(_ urlrequest: URLRequest,_ data: Data) -> Promise<(Data?, URLResponse?, CustomError?)> {
        return Promise { fulfill, reject in
            let dataTask = self.session.uploadTask(with: urlrequest, from:data) { data, response, error in
                if let error = error {
                    print ("error: \(error)")
                    reject(error)
                }
                
                guard let response = response as? HTTPURLResponse else {
                    reject(PromiseError.validationFailure)
                    return
                }
                
                if (response.statusCode == 401) {
                    // reauthorize
                    let jsonerror = try! JSONDecoder().decode(JSONError.self, from: data!)
                    print(jsonerror.code) // invalid_bucket_name
                } else if (response.statusCode == 400) {
                    // wrong fields or illegal values
                }
                
                if let mimeType = response.mimeType,
                    mimeType == "application/json",
                    let data = data {
                    fulfill((data, response, CustomError.none))
                }
            }
            dataTask.resume()
        }
    }
    
    private func authorize_account() -> Promise<(Data?, URLResponse?)> {
        
        var urlRequest = URLRequest(url: const.authorizeAccountUrl!)
        
        urlRequest.httpMethod = "GET"
        
        return get(urlRequest)
    }
    
    private func testbuckets(_ data: Data) -> Promise<(Data?, URLResponse?)> {
        
        authorization = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
        
        let request = ListBucketsRequest(accountId: (authorization?.accountId)!,
                                         bucketName: self.bucket)
        
        let uploadData = try? JSONEncoder().encode(request)
        
        let url = URL(string: "\(String(describing: authorization?.apiUrl))/b2api/v2/b2_list_buckets")
        
        var urlRequest = URLRequest(url: url!)
        
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(authorization?.authorizationToken, forHTTPHeaderField: "Authorization")
        
        return post(urlRequest, uploadData!)
    }
    
    public func list_buckets() {
        
        let request = ListBucketsRequest(accountId: "bd9db9a329de",
                                         bucketName: self.bucket)
        
        let uploadData = try? JSONEncoder().encode(request)

        let url = URL(string: "https://api000.backblazeb2.com/b2api/v2/b2_list_buckets")
        
        var urlRequest = URLRequest(url: url!)
       
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("4_000bd9db9a329de0000000002_01899283_79615e_acct_SLPdDOxMG6-shri1Y49nkttmE-E=", forHTTPHeaderField: "Authorization")
        
        let task = session.uploadTask(with: urlRequest, from: uploadData) { data, response, error in
            if let error = error {
                print ("error: \(error)")
                return
            }
            print(response.debugDescription)
            
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                    print ("server error")
                    return
            }
            
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data {
                self.buckets = try! JSONDecoder().decode(ListBucketsResponse.self, from: data)
                print(self.buckets!)
            }
        }
        task.resume()
    }
    
    
    //MARK: NSCoding
    
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(account, forKey: PropertyKey.account)
        aCoder.encode(key, forKey: PropertyKey.key)
        aCoder.encode(bucket, forKey: PropertyKey.bucket)
        aCoder.encode(versions, forKey: PropertyKey.versions)
        aCoder.encode(harddelete, forKey: PropertyKey.harddelete)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // These are required. If we cannot decode, the initializer should fail.
        guard
            let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String,
            let account = aDecoder.decodeObject(forKey: PropertyKey.account) as? String,
            let key = aDecoder.decodeObject(forKey: PropertyKey.key) as? String,
            let bucket = aDecoder.decodeObject(forKey: PropertyKey.bucket) as? String
        else
        {
            os_log("Unable to decode a B2 object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let versions = aDecoder.decodeBool(forKey: PropertyKey.versions)
        let harddelete = aDecoder.decodeBool(forKey: PropertyKey.harddelete)
        
        
        // Must call designated initializer.
        self.init(name: name, account: account, key: key, bucket: bucket, versions: versions, harddelete: harddelete)
    }
 
}
