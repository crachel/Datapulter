//
//  B2.swift
//
//
//  Created by Craig Rachel on 12/5/18.
//

import UIKit
import os.log
import Alamofire
import Promises


class B2: Provider {
    
    
    //MARK: Properties
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration,
                          delegate: self, delegateQueue: nil)
    }()
    
    struct const {
        static let apiMainURL = "https://api.backblazeb2.com/b2api/v2/b2_authorize_account"
        static let authorizeAccountUrl = URL(string: const.apiMainURL)
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
    var authorization: AuthorizeAccountResponse?
    var buckets: ListBucketsResponse?
    var uploadurl: GetUploadURLResponse?
    
    
    // Return URLRequest for attaching to Session for each supported API operation
    enum Router: Alamofire.URLRequestConvertible {
    
       
        case authorize_account(_ accountId: String,_ applicationKey: String)
        case list_buckets(_ apiUrl: String,_ accountId: String,_ accountAuthorizationToken: String,_ bucketName: String)
        case get_upload_url(_ apiUrl: String,_ accountAuthorizationToken: String,_ bucketId: String)
        case get_file_info(apiUrl: String, accountAuthorizationToken: String, fileId: String)

        
        // MARK: URLRequestConvertible
        
        
        func asURLRequest() throws -> URLRequest {
            // build a URLRequest to be attached to Session
            let result: (path: String, method: String, parameters: Parameters?, headers: String) = {
                switch self {
                case let .authorize_account(accountId, applicationKey):
                    let authNData = "\(accountId):\(applicationKey)".data(using: .utf8)?.base64EncodedString()
                    return ("\(const.apiMainURL)/b2api/v2/b2_authorize_account",
                            "GET",
                            nil, // empty body
                            "Basic \(authNData!)")
                case let .list_buckets(apiUrl, accountId, accountAuthorizationToken, bucketName):
                    return ("\(apiUrl)/b2api/v2/b2_list_buckets",
                            "POST",
                            ["accountId":accountId,"bucketName":bucketName],
                            accountAuthorizationToken)
                case let .get_upload_url(apiUrl, accountAuthorizationToken, bucketId):
                    return("\(apiUrl)/b2api/v2/b2_get_upload_url",
                           "POST",
                           ["bucketId":bucketId],
                           accountAuthorizationToken)
                case let .get_file_info(apiUrl, accountAuthorizationToken, fileId):
                    return("\(apiUrl)/b2api/v2/b2_get_file_info",
                            "POST",
                            ["fileId":fileId],
                            accountAuthorizationToken)
                }
            }()
            
            let url = try result.path.asURL()
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = result.method
            
            urlRequest.setValue("\(result.headers)", forHTTPHeaderField: "Authorization")
        
            return try JSONEncoding.default.encode(urlRequest, with: result.parameters)
        }
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
    
    
    public func test() {
        let json = """
{
    "fileId" : "4_h4a48fe8875c6214145260818_f000000000000472a_d20140104_m032022_c001_v0000123_t0104",
    "fileName" : "typing_test.txt",
    "accountId" : "d522aa47a10f",
    "bucketId" : "4a48fe8875c6214145260818",
    "contentLength" : 46,
    "contentSha1" : "bae5ed658ab3546aee12f23f36392f35dba1ebdd",
    "contentType" : "text/plain",
    "fileInfo" : {
       "author" : "unknown",
       "fileID" : "12345"
    }
}
"""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try! decoder.decode(UploadFileResponse.self, from: data)
        
        for (key, value) in response.fileInfo! {
            print("key \(key) value \(value)")
        }
        print (response)
        
    }    
    
    public func login() {
        authorize_account().then { data, response -> Promise<(Data?, URLResponse?)> in
            self.authorization = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data!)
            return self.list_buckets()
        }.then { data, response in
            self.buckets = try! JSONDecoder().decode(ListBucketsResponse.self, from: data!)
            print(self.buckets?.buckets[0].bucketId as Any)
        }.catch { error in
            print("Encountered error: \(error)")
        }
    }
    
    
    public func createAuthToken(completion:@escaping (_ authorizationToken: String,_ apiUrl: String,_ bucketId: String) -> Void) {
        
        guard let url = URL(string: const.apiMainURL) else {
            return
        }
        
        var urlRequest = URLRequest(url: url)
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
                
                completion((self.authorization?.authorizationToken)!, (self.authorization?.apiUrl)!, (self.authorization?.allowed.bucketId)!)
            }
        }
        task.resume()
    }
    
    public func getUploadURL(completion:@escaping (_ url: URL,_ uploadAuthorizationToken: String) -> Void) {
        // need auth token, apiurl, bucketid
        
        let request = try! Router.get_upload_url((authorization?.apiUrl)!, (authorization?.authorizationToken)!, (authorization?.allowed.bucketId)!).asURLRequest()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print ("error: \(error)")
                return
            }
            guard let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode) else {
                    print ("server error")
                    self.login()
                    self.getUploadURL() { url, toke in }
                    return
            }
            if let mimeType = response.mimeType,
                mimeType == "application/json",
                let data = data {
                self.uploadurl = try! JSONDecoder().decode(GetUploadURLResponse.self, from: data)
                completion(try! (self.uploadurl?.uploadUrl.asURL())!, (self.uploadurl?.authorizationToken)!)
            }
        }
        task.resume()
    }
    
    
    //MARK: Private methods
    
    
    public func fetch(_ urlrequest: URLRequest) -> Promise<(Data?, URLResponse?)> {
        return wrap { self.session.dataTask(with: urlrequest, completionHandler: $0).resume() }
    }
    
    private func authorize_account() -> Promise<(Data?, URLResponse?)> {
    
        var urlRequest = URLRequest(url: const.authorizeAccountUrl!)
        
        urlRequest.httpMethod = "GET"
        
        return fetch(urlRequest)
    }
    
    private func list_buckets() -> Promise<(Data?, URLResponse?)> {
        return try! fetch(Router.list_buckets((self.authorization?.apiUrl)!, (self.authorization?.accountId)!, (self.authorization?.authorizationToken)!, self.bucket).asURLRequest())
    }
    
    private func get_upload_url() -> Promise<(Data?, URLResponse?)> {
        return try! fetch(Router.get_upload_url((self.authorization?.apiUrl)!, (self.authorization?.authorizationToken)!, (self.buckets?.buckets[0].bucketId)!).asURLRequest())
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


//MARK: Extensions


extension B2: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    
        // limit amount of retries
        guard challenge.previousFailureCount < 5 else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        let authMethod = challenge.protectionSpace.authenticationMethod
        
        // confirm challenge method is Basic Auth else return
        guard authMethod == NSURLAuthenticationMethodHTTPBasic else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // retrieve username & password
        guard let credential = credentialsFromObject() else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        completionHandler(.useCredential, credential)
        
    }
    
    func credentialsFromObject() -> URLCredential? {
        let username = self.account
        let password = self.key
        
        return URLCredential(user: username, password: password,
                             persistence: .forSession)
    }
}
