//
//  B2.swift
//
//
//  Created by Craig Rachel on 12/5/18.
//

import UIKit
import os.log
import Alamofire
import PromiseKit

//public typealias Parameters = [String : Any]

class B2: Provider, URLSessionDelegate {
    
    
    //MARK: Properties
    
    
    struct const {
        static let apiMainURL = "https://api.backblazeb2.com"
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
    var listbucketsresponse: ListBucketsResponse?
    
    struct AuthorizeAccountResponse: Codable {
        var absoluteMinimumPartSize: Int64
        var accountId: String
        struct Allowed: Codable {
            var capabilities: [String]
            var bucketId: String?
            var bucketName: String?
            var namePrefix: String?
        }
        var apiUrl: String
        var authorizationToken: String
        var downloadUrl: String
        var recommendedPartSize: Int64
        let allowed: Allowed
    }
    
    struct Bucket: Codable {
        var accountId: String
        var bucketId: String
        struct BucketInfo: Codable {
            
        }
        var bucketName: String
        var bucketType: String
        var corsRules: [String]?
        var lifecycleRules: [String]
        var revision: Int?
        let bucketInfo: BucketInfo
    }
    
    struct ListBucketsResponse: Codable {
        var buckets: [Bucket]
    }
    
    
    // Return URLRequest for attaching to Session for each supported API operation
    enum Router: Alamofire.URLRequestConvertible {
    
       
        case authorize_account(_ accountId: String,_ applicationKey: String)
        case list_buckets(_ apiUrl: String,_ accountId: String,_ accountAuthorizationToken: String,_ bucketName: String)
        case get_upload_url(apiUrl: String, accountAuthorizationToken: String, bucketId: String)
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
    "buckets": [
    {
        "accountId": "30f20426f0b1",
        "bucketId": "4a48fe8875c6214145260818",
        "bucketInfo": {},
        "bucketName" : "Kitten-Videos",
        "bucketType": "allPrivate",
        "lifecycleRules": []
    },
    {
        "accountId": "30f20426f0b1",
        "bucketId" : "5b232e8875c6214145260818",
        "bucketInfo": {},
        "bucketName": "Puppy-Videos",
        "bucketType": "allPublic",
        "lifecycleRules": []
    },
    {
        "accountId": "30f20426f0b1",
        "bucketId": "87ba238875c6214145260818",
        "bucketInfo": {},
        "bucketName": "Vacation-Pictures",
        "bucketType" : "allPrivate",
        "lifecycleRules": []
    } ]
}
"""
        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let response = try! decoder.decode(ListBucketsResponse.self, from: data)
        print (response.buckets[0].bucketId)
        
    }

    
    public func login() {
        firstly {
            return self.authorize_account(self.account, self.key)
            }.then { data -> Promise<Data> in
                self.authorization = try! JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
                return self.list_buckets((self.authorization?.apiUrl)!, (self.authorization?.accountId)!, (self.authorization?.authorizationToken)!, self.bucket)
            }.done { data in
                self.listbucketsresponse = try! JSONDecoder().decode(ListBucketsResponse.self, from: data)
            }.catch { error in
                print(error)
        }
    }
    
    
    //MARK: Private methods
    
    
    private func authorize_account(_ accountId: String,_ applicationKey: String) -> Promise<Data> {
        return try! Client.shared.requestB2(urlrequest: Router.authorize_account(accountId, applicationKey).asURLRequest())
    }
    
    private func list_buckets(_ apiUrl: String,_ accountId: String,_ accountAuthorizationToken: String,_ bucketName: String) -> Promise<Data> {
        return try! Client.shared.requestB2(urlrequest: Router.list_buckets(apiUrl, accountId, accountAuthorizationToken, bucketName).asURLRequest())
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
