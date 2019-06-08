//
//  B2.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Photos
import Promises

class B2: Provider {
    
    //MARK: Properties
    
    var metatype: ProviderMetatype { return .b2 }
    
    struct Defaults {
        static let maxParts     = 10_000
        static let uploadCutoff = 50 * 1_000 * 1_000
        static let chunkSize    = 50 * 1_000 * 1_000
        
        static let poolMinimum  = 3
    }
    
    var account: String
    var accountId: String
    var bucket: String
    var bucketId: String
    var filePrefix: String?
    var key: String
    var name: String
    var remoteFileList: [String: Data]
    //var versions: Bool
    //var harddelete: Bool
    
    var cell: ProviderTableViewCell?
    var processingLargeFile: Bool = false
    var largeFilePool = Set<PHAsset>()
    var assetsToUpload = Set<PHAsset>()
    var uploadingAssets = [URLSessionTask: PHAsset]()
    var totalAssetsToUpload: Int = 0
    var totalAssetsUploaded: Int = 0
        
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
    
    var apiUrl: String? {
        get {
            if let result = KeychainHelper.get(account: account),
                let url = result[kSecAttrServer as String] as? String {
                return url
            } else {
                return nil
            }
        }
    }
    
    var recommendedPartSize: Int? {
        get {
            return UserDefaults.standard.integer(forKey: PropertyKey.recommendedPartSize)
        }
    }
    
    var authorizeAccountResponse: AuthorizeAccountResponse? {
        didSet {
            if let authorizeAccountResponse = authorizeAccountResponse {
                UserDefaults.standard.set(authorizeAccountResponse.recommendedPartSize, forKey: PropertyKey.recommendedPartSize)
                
                if (KeychainHelper.update(account: account, value: authorizeAccountResponse.authorizationToken, server: authorizeAccountResponse.apiUrl)) {
                    os_log("authorizationToken and apiUrl saved to Keychain", log: .b2, type: .info)
                } else {
                    os_log("problem saving authorizationToken to Keychain", log: .b2, type: .error)
                }
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
        case apiUrlNotSet
        
        var localizedDescription: String {
            switch self {
            case .bad_request: return "bad request"
            case .unauthorized: return "unauthorized"
            case .bad_auth_token: return "bad auth token"
            case .expired_auth_token: return "expired auth token"
            case .cap_exceeded: return "cap exceeded"
            case .method_not_allowed: return "method not allowed"
            case .request_timeout: return "request timeout"
            case .service_unavailable: return "service unavailable"
            case .unmatchedError: return "unmatched error"
            case .apiUrlNotSet: return "apiurl not set"
            }
        }
    }
    
    struct Endpoints {
        // Transactions Class A (unlimited number free)
        static let finishLargeFile  = Endpoint(path: "/b2api/v2/b2_finish_large_file")
        static let getUploadUrl     = Endpoint(path: "/b2api/v2/b2_get_upload_url")
        static let getUploadPartUrl = Endpoint(path: "/b2api/v2/b2_get_upload_part_url")
        static let startLargeFile   = Endpoint(path: "/b2api/v2/b2_start_large_file")
        static let uploadFile       = Endpoint(path: "/b2api/v2/b2_upload_file")
        static let uploadPart       = Endpoint(path: "/b2api/v2/b2_upload_part")
        
        // Transactions Class C ($0.004 per 1,000)
        static let authorizeAccount: Endpoint = {
            var components = URLComponents()
            components.scheme = "https"
            components.host   = "api.backblazeb2.com"
            components.path   = "/b2api/v2/b2_authorize_account"
            return Endpoint(components: components, method: HTTPMethod.get)
        }()
        static let listFileNames    = Endpoint(path: "/b2api/v2/b2_list_file_names")
        static let listFileVersions = Endpoint(path: "/b2api/v2/b2_list_file_versions")
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
        var recommendedPartSize: Int
        var downloadUrl: String
        let allowed: Allowed
    }
    
    struct GetUploadURLResponse: Codable {
        var bucketId: String
        var uploadUrl: URL
        var authorizationToken: String
    }
    
    struct File: Codable {
        var accountId: String
        var action: String
        var bucketId: String
        var contentLength: Int64
        var contentSha1: String?
        var contentType: String
        var fileId: String
        var fileInfo: [String:String]?
        var fileName: String
        var uploadTimestamp: Int64
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
        static let filePrefix          = "filePrefix"
        
        static let authorizationToken  = "authorizationToken"
        static let apiUrl              = "apiUrl"
        static let recommendedPartSize = "recommendedPartSize"
    }

    //MARK: Initialization
    
    init(name: String, account: String, key: String, bucket: String, accountId: String, bucketId: String, remoteFileList: [String: Data], filePrefix: String?) {
        self.account = account
        self.key = key
        self.bucket = bucket
        //versions: Bool, harddelete: Bool,
        //self.versions = versions
        //self.harddelete = harddelete
        self.accountId = accountId
        self.bucketId = bucketId
        self.filePrefix = filePrefix
        
        self.name = name
        self.remoteFileList = remoteFileList
        
        //_ = KeychainHelper.update(account: account, value: "badtoken", server: apiUrl!)
    }
    
    //MARK: Public methods
    
    func authorize() -> Promise<Bool> {
    return self.authorizeAccount().then { data, _ in
        Utility.objectIsType(object: data, someObjectOfType: Data.self)
    }.then { data in
        try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
    }.then { parsedResult in
        self.authorizeAccountResponse = parsedResult
    }.then {
        return true
    }
}
    
    func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)> {
    struct GetUploadURLRequest: Codable {
        var bucketId: String
    }
    
    if (asset.size > Defaults.uploadCutoff ) {
        
        if(processingLargeFile) {
            largeFilePool.insert(asset)
        } else {
            processingLargeFile = true
            do {
                try processLargeFile(asset)
            } catch {
                os_log("processingLargeFile %@", log: .b2, type: .error, error.localizedDescription)
            }
        }
        
        return Promise(ProviderError.largeFile) //need to return here so we don't try to process large file anyway
    }
    
    func buildUploadFileRequest(from asset: PHAsset, with result: GetUploadURLResponse) -> Promise<(URLRequest?, Data?)> {
        return Promise { fulfill, reject in
            var urlRequest = URLRequest(url: result.uploadUrl)
            
            urlRequest.httpMethod = HTTPMethod.post
            
            urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
            urlRequest.setValue(HTTPHeaders.contentTypeValue, forHTTPHeaderField: HTTPHeaders.contentType)
            urlRequest.setValue(String(asset.size), forHTTPHeaderField: HTTPHeaders.contentLength)
            
            //urlRequest.setValue("fail_some_uploads",forHTTPHeaderField: "X-Bz-Test-Mode")
            
            if var fileName = asset.percentEncodedFilename {
                if let prefix = self.filePrefix {
                    fileName = prefix.addingSuffixIfNeeded("/") + fileName
                }
                //urlRequest.setValue(self.filePrefix.addingSuffixIfNeeded("/") + fileName, forHTTPHeaderField: HTTPHeaders.fileName)
                urlRequest.setValue(fileName, forHTTPHeaderField: HTTPHeaders.fileName)
            } else {
                reject(ProviderError.foundNil)
            }
            
            if let unixCreationDate = asset.creationDate?.millisecondsSince1970  {
                urlRequest.setValue(String(unixCreationDate), forHTTPHeaderField: HTTPHeaders.time)
            } else {
                reject(ProviderError.foundNil)
            }
            
            Utility.getData(from: asset) { data, _ in
                urlRequest.setValue(data.sha1, forHTTPHeaderField: HTTPHeaders.sha1)
                
                fulfill((urlRequest, data))
            }
        }
    }

    if (pool.count > Defaults.poolMinimum) {
        if let data = pool.dequeue() {
            return buildUploadFileRequest(from: asset, with: data)
        }
    }
    
    let request = GetUploadURLRequest(bucketId: bucketId)
    
    var uploadData: Data
    do {
        uploadData = try JSONEncoder().encode(request)
    } catch {
        return Promise(error)
    }
    
    os_log("fetching getUploadUrl", log: .b2, type: .info)
    
    return self.fetch(from: Endpoints.getUploadUrl, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
        self.recover(from: error, retry: Endpoints.getUploadUrl, with: uploadData)
    }.then { data, _ in
        Utility.objectIsType(object: data, someObjectOfType: Data.self)
    }.then { data in
        try JSONDecoder().decode(GetUploadURLResponse.self, from: data)
    }.then { result in
        buildUploadFileRequest(from: asset, with: result)
    }
}

    func decodeURLResponse(_ response: HTTPURLResponse,_ data: Data?,_ task: URLSessionTask,_ asset: PHAsset) {
       
        if let originalRequest = task.originalRequest,
            let allHeaders = originalRequest.allHTTPHeaderFields,
            let originalUrl = originalRequest.url,
            let data = data {
            
            if (originalUrl.path.contains(Endpoints.uploadFile.components.path)) { // alternative could be [URLRequest:Endpoint]
                if (response.statusCode == 200) {
                    
                    finishUploadOperation(asset.localIdentifier, data)
                    
                    var file: File
                    
                    do {
                        file = try JSONDecoder().decode(File.self, from: data)
                    } catch {
                        return
                    }
                    
                    if let token = allHeaders["Authorization"] {
                        let getUploadURLResponse = GetUploadURLResponse(bucketId: file.bucketId,
                                                                        uploadUrl: originalUrl,
                                                                        authorizationToken: token)
                        
                        pool.enqueue(getUploadURLResponse)
                    } else {
                        os_log("problem retrieving token from allHeaders", log: .b2, type: .error)
                    }
                    
                    AutoUpload.shared.initiate(1, self)
                } else {
                    /*
                     "File not uploaded. If possible the server will return a JSON error structure."
                     */
                    
                    var jsonError: JSONError
                    
                    do {
                        jsonError = try JSONDecoder().decode(JSONError.self, from: data)
                    } catch {
                        return
                    }
                    
                    switch jsonError.code {
                    case B2Error.bad_auth_token.rawValue, B2Error.expired_auth_token.rawValue, B2Error.service_unavailable.rawValue:
                        os_log("%@: reinsterting asset and initiating new request", log: .b2, type: .error, jsonError.code)
                        /*
                         Call b2_get_upload_url again to get a new auth token.
                         */
                        assetsToUpload.insert(asset)
                        
                        AutoUpload.shared.initiate(1, self)
                    default:
                        os_log("%@", log: .b2, type: .error, jsonError.code)
                    }
                }
            } // else if (originalUrl.path.contains(Endpoints.uploadFile.components.path))
        } else {
            if (data == nil) {
                os_log("no Data sent to decodeURLResponse. ignoring.", log: .b2, type: .info)
            }
        }
    }
    
    func willDelete() {
        _ = KeychainHelper.delete(account: account)
    }
    
    func check() {
        
        struct ListFileVersionsRequest: Codable {
            var bucketId: String
            var startFileName: String?
            var startFileId: String?
            var maxFileCount: Int64?
            var prefix: String?
            var delimiter: String?
        }
        
        struct ListFileVersionsResponse: Codable {
            var files: [File]
            var nextFileName: String?
            var nextFileId: String?
        }
        
        var rfl:Int64 = 0
        
        for file in remoteFileList {
            do {
                //let response = try JSONDecoder().decode(UploadFileResponse.self, from: file.value)
                let response = try JSONDecoder().decode(File.self, from: file.value)
                rfl += response.contentLength
            } catch {
                print(error)
            }
        }
        print ("remotefilelist.count \(remoteFileList.count)")
        print ("ffl \(rfl)")
        var totalRemoteSize:Int64 = 0
        var totalObjects = 0
        
        func iterate(_ startFileName: String? = nil,_ startFileId: String? = nil) {
            
            let request = ListFileVersionsRequest(bucketId: bucketId,
                                                  startFileName: startFileName,
                                                  startFileId: startFileId,
                                                  maxFileCount: 100,
                                                  prefix: "simulator/",
                                                  delimiter: "/")
            
            var uploadData: Data
            do {
                uploadData = try JSONEncoder().encode(request)
            } catch {
                return
            }
            
            os_log("Transactions Class C - %@", log: .b2, type: .info, Endpoints.listFileVersions.components.path)
            
            self.fetch(from: Endpoints.listFileVersions, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
                self.recover(from: error, retry: Endpoints.listFileVersions, with: uploadData)
            }.then { data, _ in
                Utility.objectIsType(object: data, someObjectOfType: Data.self)
            }.then { data in
                try JSONDecoder().decode(ListFileVersionsResponse.self, from: data)
            }.then { result in
                
                for file in result.files {
                    if(file.action == "upload") {
                        totalObjects += 1
                    }
                    totalRemoteSize += file.contentLength
                }
                if(result.nextFileId == nil) {
                    print("totalObjects \(totalObjects)")
                    print("totalRemoteSize \(totalRemoteSize)")
                } else {
                    iterate(result.nextFileName, result.nextFileId)
                }
                
            }.catch { error in
                print(error)
            }
        }
        
        iterate()
    
    }
    
    //MARK: Private methods
    
    private func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        guard let authNData = "\(account):\(key)".data(using: .utf8)?.base64EncodedString() else {
            return Promise(ProviderError.preparationFailed)
        }
        
        guard let url = Endpoints.authorizeAccount.components.url else {
            return Promise(ProviderError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = HTTPMethod.get
        urlRequest.setValue("Basic \(authNData)", forHTTPHeaderField: HTTPHeaders.authorization)
        
        os_log("Transactions Class C - %@", log: .b2, type: .info, Endpoints.authorizeAccount.components.path)
        
        return fetch(from: urlRequest)
    }
    
    private func fetch(from endpoint: Endpoint, with uploadData: Data? = nil) -> Promise<(Data?, URLResponse?)> {
        
        guard let apiUrl = apiUrl else {
            return Promise(B2Error.apiUrlNotSet)
        }
        
        guard let url = URL(string: "\(apiUrl)\(endpoint.components.path)") else {
            return Promise(ProviderError.preparationFailed)
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
    
    private func recover(from error: Error,retry endpoint: Endpoint,with uploadData: Data) -> Promise<(Data?, URLResponse?)> {
        
        func retry() -> Promise<(Data?, URLResponse?)> {
            os_log("bad or expired auth token. attempting refresh then retrying API call", log: .b2, type: .error)
            return self.authorizeAccount().then { data, _ in
                Utility.objectIsType(object: data, someObjectOfType: Data.self)
            }.then { data in
                try JSONDecoder().decode(AuthorizeAccountResponse.self, from: data)
            }.then { parsedResult in
                self.authorizeAccountResponse = parsedResult
            }.then {
                self.fetch(from: endpoint, with: uploadData) // retry call
            }
        }
        
        switch error {
        case ProviderError.validResponse(let data):
            /**
             A valid response other than 200 was received. Decode the json data
             and then determine if it is recoverable.
             */
            
            var jsonerror: JSONError
            
            do {
                jsonerror = try JSONDecoder().decode(JSONError.self, from: data)
            } catch {
                return Promise(ProviderError.invalidJson) // unknown problem decoding JSON
            }
            
            switch(jsonerror.code) {
            case B2Error.bad_auth_token.rawValue, B2Error.expired_auth_token.rawValue:
                return retry() // error appears to be recoverable
            default:
                return Promise(error) // error is not recoverable
            }
        case B2Error.bad_auth_token, B2Error.expired_auth_token, B2Error.apiUrlNotSet:
            return retry()
        case ProviderError.connectionError:
            return self.fetch(from: endpoint, with: uploadData) // retry call
        default:
            return Promise(error)
        }
    }
    
    private func processLargeFile(_ asset: PHAsset) throws {
        
        struct StartLargeFileRequest: Codable {
            var bucketId: String
            var fileName: String
            var contentType: String
        }
        
        struct StartLargeFileResponse: Codable {
            var accountId: String
            var action: String
            var bucketId: String
            var contentLength: Int64
            var contentSha1: String
            var contentType: String
            var fileId: String
            var fileName: String
            var uploadTimestamp: Int64
            var fileInfo: [String: String]?
            
            /*
            private enum CodingKeys: String, CodingKey {
                case accountId
                case action
                case bucketId
                case contentLength
                case contentSha1
                case contentType
                case fileId
                case fileName
                case uploadTimestamp
                case fileInfo
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                accountId = try container.decode(String.self, forKey: .accountId)
                action = try container.decode(String.self, forKey: .action)
                bucketId = try container.decode(String.self, forKey: .bucketId)
                contentLength = try container.decode(Int64.self, forKey: .contentLength)
                contentSha1 = try container.decode(String.self, forKey: .contentSha1)
                contentType = try container.decode(String.self, forKey: .contentType)
                fileId = try container.decode(String.self, forKey: .fileId)
                fileName = try container.decode(String.self, forKey: .fileName)
                uploadTimestamp = try container.decode(Int64.self, forKey: .uploadTimestamp)
                
                fileInfo = [String: String]()
                let subContainer = try container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: .fileInfo)
                for key in subContainer.allKeys {
                    fileInfo?[key.stringValue] = try subContainer.decode(String.self, forKey: key)
                }
                
            }*/
            
        }
        
        struct FinishLargeUploadRequest: Codable {
            var fileId: String
            var partSha1Array: [String]
        }
        
        func createParts(_ asset: PHAsset,_ fileId: String) -> Promise<(String, [String])>  {
            
            struct GetUploadPartURLRequest: Codable {
                var fileId: String
            }
            
            struct GetUploadPartURLResponse: Codable {
                var fileId: String
                var uploadUrl: URL
                var authorizationToken: String
            }
            
            return Promise { fulfill, reject in
                Utility.getURL(ofPhotoWith: asset) { url in
                    
                    let payloadFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    
                    var partSha1Array = [String]()
                    var part = 0
                    
                    if let url = url,
                        let inputStream = InputStream.init(url: url),
                        FileManager.default.createFile(atPath: payloadFileURL.path, contents: nil, attributes: nil) {
                        
                        inputStream.open()
                        
                        var buffer = [UInt8](repeating: 0, count: Defaults.chunkSize)
                        var bytes = 0
                        
                        func readBytes() {
                            
                            bytes = inputStream.read(&buffer, maxLength: Defaults.chunkSize)
                            
                            if (bytes > 0 && part < Defaults.maxParts) {
                                part += 1
                                
                                let data = Data(bytes: buffer, count: bytes)
                                partSha1Array.append(data.sha1)
                                
                                do {
                                    let file = try FileHandle(forWritingTo: payloadFileURL)
                                    file.write(data)
                                    file.truncateFile(atOffset: UInt64(bytes))
                                    file.closeFile()
                                } catch {
                                    reject (error)
                                }
                                
                                buildUploadPartRequest().then { _, _ in
                                    readBytes()
                                }
                                
                            } else {
                                do {
                                    try FileManager.default.removeItem(at: payloadFileURL)
                                } catch let error as NSError {
                                    os_log("error removing payloadFileURL. %@", log: .b2, type: .error, error.domain)
                                }
                                
                                inputStream.close()
                                
                                fulfill((fileId, partSha1Array))
                            }
                        }
                        readBytes()
                        
                        func buildUploadPartRequest() -> Promise<(Data?, URLResponse?)> {
                            var uploadData: Data
                            
                            do {
                                uploadData = try JSONEncoder().encode(GetUploadPartURLRequest(fileId: fileId))
                            } catch {
                                return Promise(error)
                            }
                            
                            return self.fetch(from: Endpoints.getUploadPartUrl, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
                                self.recover(from: error, retry: Endpoints.getUploadPartUrl, with: uploadData)
                                }.then { data, _ in
                                    Utility.objectIsType(object: data, someObjectOfType: Data.self)
                                }.then { data in
                                    try JSONDecoder().decode(GetUploadPartURLResponse.self, from: data)
                                }.then { parsedResponse in
                                    uploadPart(parsedResponse, bytes, payloadFileURL, part, partSha1Array.last!)
                            }
                        }
                        
                        func uploadPart(_ result: GetUploadPartURLResponse,_ dataCount: Int,_ url: URL,_ partNumber: Int,_ sha1: String) -> Promise<(Data?, URLResponse?)> {
                            var urlRequest = URLRequest(url: result.uploadUrl)
                            
                            urlRequest.httpMethod = HTTPMethod.post
                            
                            urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: HTTPHeaders.authorization)
                            urlRequest.setValue(String(partNumber), forHTTPHeaderField: HTTPHeaders.partNumber)
                            urlRequest.setValue(String(dataCount), forHTTPHeaderField: HTTPHeaders.contentLength)
                            urlRequest.setValue(sha1, forHTTPHeaderField: HTTPHeaders.sha1)
                            
                            return self.fetch(from: urlRequest, from: url).recover { error -> Promise<(Data?, URLResponse?)> in
                                switch error {
                                case B2Error.bad_auth_token, B2Error.expired_auth_token, B2Error.service_unavailable:
                                    return buildUploadPartRequest()
                                case ProviderError.connectionError:
                                    return self.fetch(from: urlRequest, from: url)
                                default:
                                    return Promise(error)
                                }
                            }
                        }
                    }
                }
            }
        
        }
        
        guard var fileName = asset.originalFilename else {
            throw ProviderError.foundNil
        }
        
        if let prefix = filePrefix {
            fileName = prefix.addingSuffixIfNeeded("/") + fileName
        }
        
        let request = StartLargeFileRequest(bucketId: bucketId,
                                            fileName: fileName,
                                            //fileName: self.filePrefix.addingSuffixIfNeeded("/") + fileName,
                                            contentType: HTTPHeaders.contentTypeValue)
        
        var uploadData: Data
        
        do {
            uploadData = try JSONEncoder().encode(request)
        } catch {
            throw ProviderError.preparationFailed
        }
        
        self.fetch(from: Endpoints.startLargeFile, with: uploadData).recover { error -> Promise<(Data?, URLResponse?)> in
            self.recover(from: error, retry: Endpoints.startLargeFile, with: uploadData)
        }.then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            try JSONDecoder().decode(StartLargeFileResponse.self, from: data)
        }.then { parsedResult in
            createParts(asset, parsedResult.fileId) // loops. breaks file into chunks & uploads them
        }.then { fileId, partSha1Array in
            try JSONEncoder().encode(FinishLargeUploadRequest(fileId: fileId, partSha1Array: partSha1Array))
        }.then { uploadData in
            self.fetch(from: Endpoints.finishLargeFile, with: uploadData)
        }.recover { error -> Promise<(Data?, URLResponse?)> in
            self.recover(from: error, retry: Endpoints.finishLargeFile, with: uploadData)
        }.then { data, response in
            if let data = data,
               let response = response as? HTTPURLResponse {
                if (response.statusCode == 200) {
                    
                    self.finishUploadOperation(asset.localIdentifier, data)
                   
                    if (self.largeFilePool.isEmpty) {
                        self.processingLargeFile = false // ends here
                    } else {
                        if let newAsset = self.largeFilePool.popFirst() {
                            try self.processLargeFile(newAsset)
                        } else {
                            throw ProviderError.foundNil
                        }
                    }
                }
            } else {
                throw ProviderError.invalidResponse
            }
        }
    }
    
    private func finishUploadOperation(_ localIdentifier: String,_ data: Data) {
        /*
         remoteFileList should be indexed by the assetlocalidentifier.
         cant use sha1 as index bc a user may have a movie that's 500MB.
         the data should be an object thats easy to parse for calculating
         total size of this user's remote dir.
         
         so each data response needs to be encoded then converted to this
         new object type. also needs to be storable in cloudkit or similar.
         ***WRONG: append raw JSONdata and worry about decoding when data is
         actually needed. Data easier to work with than some custom Struct
         
         sha1 exists for all but large files. should be useful should localidentifier
         not actually be persistent as apple claims. could also check times/names
         
         the final interfacing between cloudkit should be handled by Autoupload
         by passing self + this new object type
         */
        
        remoteFileList[localIdentifier] = data
        
        totalAssetsUploaded += 1
        
        updateRing()
        
        ProviderManager.shared.saveProviders()
    }
    
    //MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case account
        case accountId
        case bucket
        case bucketId
        case filePrefix
        case key
        case name
        case remoteFileList
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(account, forKey: .account)
        try container.encode(accountId, forKey: .accountId)
        try container.encode(bucket, forKey: .bucket)
        try container.encode(bucketId, forKey: .bucketId)
        try container.encode(filePrefix, forKey: .filePrefix)
        try container.encode(key, forKey: .key)
        try container.encode(name, forKey: .name)
        try container.encode(remoteFileList, forKey: .remoteFileList)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        account = try values.decode(String.self, forKey: .account)
        accountId = try values.decode(String.self, forKey: .accountId)
        bucket = try values.decode(String.self, forKey: .bucket)
        bucketId = try values.decode(String.self, forKey: .bucketId)
        filePrefix = try values.decode(String.self, forKey: .filePrefix)
        key = try values.decode(String.self, forKey: .key)
        name = try values.decode(String.self, forKey: .name)
        remoteFileList = try values.decode([String:Data].self, forKey: .remoteFileList)
    }
    
}
