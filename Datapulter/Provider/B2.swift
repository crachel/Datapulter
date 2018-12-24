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

final class B2: Provider {
    
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
        static let minChunkSize = 5 * 1024 * 1024
        static let defaultChunkSize = 96 * 1024 * 1024
        static let defaultUploadCutoff = 200 * 1024 * 1024
    }

    var account: String
    var key: String
    var bucket: String
    var versions: Bool
    var harddelete: Bool
    var uploadList: [String: String] // Filename : fileId
    
    
    // Return URLRequest for attaching to Session for each supported API operation
    enum Router: Alamofire.URLRequestConvertible {
       
        case authorize_account(accountId: String, applicationKey: String)
        case list_buckets(apiUrl: String, accountId: String, accountAuthorizationToken: String, bucketName: String)
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
    
    struct APIResponse {
        var root: String // the path we are working on if any
        
        var accountId: String
        var authorizationToken: String
        var allowed: [String: Any]
        var apiUrl: String
        var downloadUrl: String
        var uploadUrl: String
        var recommendedPartSize: Int64
        var absoluteMinimumPartSize: Int64
        //opt           Options                      // parsed config options
        //features      *fs.Features                 // optional features
        //srv           *rest.Client                 // the connection to the b2 server
        //var bucket: String                       // the bucket we are working on
        //bucketOKMu    sync.Mutex                   // mutex to protect bucket OK
        //bucketOK      bool                         // true if we have created the bucket
        //bucketIDMutex sync.Mutex                   // mutex to protect _bucketID
        //var _bucketID: String                       // the ID of the bucket we are working on
        //info          api.AuthorizeAccountResponse // result of authorize call
        //uploadMu      sync.Mutex                   // lock for upload variable
        //uploads       []*api.GetUploadURLResponse  // result of get upload URL calls
        //authMu        sync.Mutex                   // lock for authorizing the account
        //pacer         *pacer.Pacer                 // To pace and retry the API calls
        //bufferTokens  chan []byte                  // control concurrency of multipart uploads
    }
    
    // Object describes a b2 object
    struct Object {
        //fs       *Fs          // what this object is part of
        var remote: String      // The remote path
        var id: String          // b2 id of the file
        var modTime: Date       // The modified time of the object if known
        var sha1: String        // SHA-1 hash if known
        var size: Int64         // Size of the object
        var mimeType: String    // Content-Type of the object
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
        self.uploadList = [:] // empty
        
        super.init(name: name, backend: .Backblaze)
    }
    
    init(name: String, account: String, key: String, bucket: String, versions: Bool, harddelete: Bool, uploadList: Dictionary<String, String>) {
    // init for decoding existing provider
        self.account = account
        self.key = key
        self.bucket = bucket
        self.versions = versions
        self.harddelete = harddelete
        self.uploadList = uploadList
        
        super.init(name: name, backend: .Backblaze)
    }
    
    //MARK: Public methods
    
    /*
    public func login() {
        //return try! Router.authorize_account(accountId: self.account, applicationKey: self.key).asURLRequest()
        try! self.autoupload.request(urlrequest: Router.authorize_account(accountId: self.account, applicationKey: self.key).asURLRequest()).then
        { json -> Promise<JSON> in
            return try! self.autoupload.request(urlrequest: Router.list_buckets(apiUrl: json["apiUrl"] as! String, accountId: json["accountId"] as! String, accountAuthorizationToken: json["authorizationToken"] as! String, bucketName: self.bucket).asURLRequest())
            //json["profileId"]
        }.done { foo in
            // handle successful request
        }.catch { error in
            // handle error
        }
    }*/
    
    //MARK: NSCoding
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(account, forKey: PropertyKey.account)
        aCoder.encode(key, forKey: PropertyKey.key)
        aCoder.encode(bucket, forKey: PropertyKey.bucket)
        aCoder.encode(versions, forKey: PropertyKey.versions)
        aCoder.encode(harddelete, forKey: PropertyKey.harddelete)
        aCoder.encode(uploadList, forKey: PropertyKey.uploadList)
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
        let uploadList = aDecoder.decodeObject(forKey: PropertyKey.uploadList)
        
        
        // Must call designated initializer.
        self.init(name: name, account: account, key: key, bucket: bucket, versions: versions, harddelete: harddelete, uploadList: uploadList as! Dictionary<String, String>)
    }
 
}
