//
//  S3.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/15/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Photos
import Promises

class S3: Provider {
    
    //MARK: Properties
    
    var metatype: ProviderMetatype { return .s3 }
    
    struct Defaults {
        static let maxParts     = 10_000
        static let uploadCutoff = 50 * 1_000 * 1_000
        static let chunkSize    = 50 * 1_000 * 1_000
    }

    var cell: ProviderTableViewCell?
    var processingLargeFile: Bool = false
    var largeFilePool = Set<PHAsset>()
    var assetsToUpload = Set<PHAsset>()
    var uploadingAssets = [URLSessionTask: PHAsset]()
    var totalAssetsToUpload: Int = 0
    var totalAssetsUploaded: Int = 0
    
    var accessKeyID: String
    var bucket: String
    var hostName: String
    var name: String
    var regionName: String
    var remoteFileList: [String: Data]
    var secretAccessKey: String
    
    //MARK: Types
    
    struct AuthorizationHeader {
        static let signatureVersion = "AWS4"
        static let signatureRequest = "aws4_request"
        static let signingAlgorithm = "AWS4-HMAC-SHA256"
        static let serviceName      = "s3"
    }
    
    struct HTTPHeaders {
        static let authorization = "authorization"
        static let date          = "x-amz-date"
        static let mimeType      = "application/json"
        static let contentLength = "content-length"
        static let contentType   = "content-type"
        static let contentMD5    = "content-md5"
        static let expect        = "expect" // 100-continue
        static let host          = "host"
        static let contentSHA256 = "x-amz-content-sha256"
        static let prefix        = "x-amz-meta-"
        static let modified      = prefix + "src_last_modified_millis"
        static let fileName      = prefix + "file-name"
    }
    
    struct File: Codable {
        // x-amz-content-sha256
        // x-amz-meta-src_last_modified_millis
        // Content-Length
        // X-Amz-Date
        var accessKeyID: String
        var bucket: String
        var contentLength: Int64
        var contentSha1: String?
        var contentType: String
        var fileName: String
        var uploadTimestamp: Int64
    }
    
    //MARK: Initialization
    
    init(name: String, accessKeyID: String, secretAccessKey: String, bucket: String, regionName: String, hostName: String, remoteFileList: [String:Data]) {
        self.accessKeyID = accessKeyID
        self.bucket = bucket
        self.hostName = hostName
        self.name = name
        self.regionName = regionName
        self.remoteFileList = remoteFileList
        self.secretAccessKey = secretAccessKey
    }
    
    //MARK: Public methods
    
    func authorize() -> Promise<Bool> {
        return Promise(true)
    }
    
    func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)> {
        
        guard let assetFileName = asset.originalFilename else {
            return Promise(ProviderError.foundNil)
        }
        
        let putObject: Endpoint = {
            var components = URLComponents()
            components.host = [bucket, hostName].joined(separator: ".")
            components.path = assetFileName.addingPrefixIfNeeded("/")
            return Endpoint(components: components)
        }()
        
        let date      = Date().iso8601
        let dateStamp = Date.getFormattedDate()
        
        if (asset.size > Defaults.uploadCutoff ) {
            
            if (processingLargeFile) {
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
        
        guard let fullHost = putObject.components.host else {
            return Promise(ProviderError.preparationFailed)
        }
        
        guard let url = putObject.components.url else {
            return Promise(ProviderError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = HTTPMethod.put
        urlRequest.setValue(String(asset.size), forHTTPHeaderField: HTTPHeaders.contentLength)
        urlRequest.setValue(date, forHTTPHeaderField: HTTPHeaders.date)
        urlRequest.setValue("100-continue", forHTTPHeaderField: HTTPHeaders.expect)
        
        let unixCreationDate = asset.creationDate?.millisecondsSince1970
        
        urlRequest.setValue((unixCreationDate?.description), forHTTPHeaderField: HTTPHeaders.modified)

        return Promise { fulfill, reject in
            Utility.getData(from: asset) { data, _ in
                
                let hashedPayload = data.sha256
                
                urlRequest.setValue(hashedPayload, forHTTPHeaderField: HTTPHeaders.contentSHA256)
   
                let headers = [HTTPHeaders.contentLength: String(asset.size),
                               HTTPHeaders.expect:"100-continue",
                               HTTPHeaders.host:fullHost,
                               HTTPHeaders.contentSHA256:hashedPayload,
                               HTTPHeaders.date:date,
                               HTTPHeaders.modified:String(unixCreationDate!)]
                
                var authorizationHeader = String()
                
                switch self.getAuthorizationHeader(method: HTTPMethod.put, endpoint: putObject, headers: headers, hashedPayload: hashedPayload, date: date, dateStamp: dateStamp) {
                case .success(let result):
                    authorizationHeader = result
                case .failure(let error):
                    reject(error)
                }
    
                urlRequest.setValue(authorizationHeader, forHTTPHeaderField: HTTPHeaders.authorization)
                
                fulfill((urlRequest, data))
            }
        }
    }
    
    func decodeURLResponse(_ response: HTTPURLResponse,_ data: Data?,_ task: URLSessionTask,_ asset: PHAsset) {
        if let originalRequest = task.originalRequest,
            var allHeaders = originalRequest.allHTTPHeaderFields {
            if (originalRequest.httpMethod == HTTPMethod.put) {
                if (response.statusCode == 200) {
                    
                    allHeaders["fileName"] = asset.originalFilename
                    
                    print("allHeaders \(allHeaders)")
                    do {
                        let data = try JSONSerialization.data(withJSONObject: allHeaders, options: [])
                        remoteFileList[asset.localIdentifier] = data
                    } catch {
                        os_log("Unable to serialize an S3 response. %@", log: .s3, type: .error, error.localizedDescription)
                    }
                    
                    totalAssetsUploaded += 1
                    
                    updateRing()
                    
                    ProviderManager.shared.saveProviders()
                    
                    AutoUpload.shared.initiate(1, self)
                } else {
                    // parse xml and figure out what happened. decide course of action
                }
            }
        }
    }
    
    func willDelete() {
        print("willoverride")
    }
    
    func check() {
        
    }
    
    //MARK: Private methods
    
    private func getAuthorizationHeader(method: String, endpoint: Endpoint, headers: [String:String], hashedPayload: String, date: String, dateStamp: String) -> Result<String, Error> {
        
        func getSigningKey() -> Result<Data, ProviderError>  {
            
            guard let kSecret = (AuthorizationHeader.signatureVersion + self.secretAccessKey).data(using: .utf8) else {
                return .failure(.foundNil)
            }
            
            let kDate    = dateStamp.hmac_sha256(key: kSecret)
            let kRegion  = regionName.hmac_sha256(key: kDate)
            let kService = AuthorizationHeader.serviceName.hmac_sha256(key: kRegion)
            let kSigning = AuthorizationHeader.signatureRequest.hmac_sha256(key: kService)
            
            return .success(kSigning)
        }
        
        let canonicalURI = endpoint.components.percentEncodedPath
        
        let signedHeaders = headers.keys.sorted().joined(separator: ";")
        
        let canonicalHeaders = headers.compactMap({ (key, value) -> String in
            return "\(key):\(value)"
        }).sorted().joined(separator: "\n")
        
        //take the percentencodequery off this and possibly the equal sign
        //let canonicalQueryString = endpoint.components.percentEncodedQuery?.addingSuffixIfNeeded("=") ?? ""
        //let canonicalQueryString = endpoint.components.query?.addingSuffixIfNeeded("=") ?? ""
        let canonicalQueryString = endpoint.components.queryItems?.compactMap({ queryItem -> String in
            return "\(queryItem.name)=\(queryItem.value ?? "")"
        //}).joined(separator: "&amp;") ?? ""
        }).joined(separator: "&") ?? ""
        
        let canonicalRequest = """
        \(method)
        \(canonicalURI)
        \(canonicalQueryString)
        \(canonicalHeaders)
        
        \(signedHeaders)
        \(hashedPayload)
        """
        
        print("canrequest \(canonicalRequest)")
        
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(date)
        \(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest)
        \(canonicalRequest.data(using: .utf8)!.sha256)
        """
        print("stringtosign \(stringToSign)")
        
        var signature: Data
        
        switch getSigningKey() {
        case .success(let kSigning):
            signature = stringToSign.hmac_sha256(key: kSigning)
        case .failure(let error):
            return .failure(error)
        }
        
        let authorizationHeader = "AWS4-HMAC-SHA256 Credential=\(self.accessKeyID)/\(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest),SignedHeaders=\(signedHeaders),Signature=\(signature.hex)"
        
        return .success(authorizationHeader)
    }
    
    private func processLargeFile(_ asset: PHAsset) throws {
        
        guard let assetFileName = asset.originalFilename else {
            throw (ProviderError.foundNil)
        }
        
        let queryItemToken = URLQueryItem(name: "uploads", value: nil)
        
        let putObject: Endpoint = {
            var components = URLComponents()
            components.host       = [bucket, hostName].joined(separator: ".")
            components.path       = assetFileName.addingPrefixIfNeeded("/")
            components.queryItems = [queryItemToken]
            return Endpoint(components: components)
        }()
        
        let date      = Date().iso8601
        let dateStamp = Date.getFormattedDate()
        
        let hashedPayload = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        
        guard let fullHost = putObject.components.host else {
            throw (ProviderError.preparationFailed)
        }
        
        let headers = [HTTPHeaders.host: fullHost,
                       HTTPHeaders.contentSHA256: hashedPayload,
                       HTTPHeaders.date: date]
        
        var header: String
        
        let headerResult = getAuthorizationHeader(method: HTTPMethod.post, endpoint: putObject, headers: headers, hashedPayload: hashedPayload, date: date, dateStamp: dateStamp)
        
        switch headerResult {
        case .success(let result):
            header = result
        case .failure(let error):
            throw error
        }
        
        guard let url = putObject.components.url else {
            throw (ProviderError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = HTTPMethod.post
        
        urlRequest.setValue(hashedPayload, forHTTPHeaderField: HTTPHeaders.contentSHA256)
        urlRequest.setValue(date, forHTTPHeaderField: HTTPHeaders.date)
        urlRequest.setValue(header, forHTTPHeaderField: HTTPHeaders.authorization)
        
        fetch(from: urlRequest).then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            XMLHelper(data:data, recordKey: "InitiateMultipartUploadResult", dictionaryKeys: ["Bucket", "Key", "UploadId"]).go()
        }.then { responseDictionary in
            print (responseDictionary)
            createParts(asset, (responseDictionary?.first!["UploadId"])!)
        }.catch { error in
            switch error {
            case ProviderError.validResponse(let data):
                print(String(data:data, encoding:.utf8)!)
                let xmlerror = XMLHelper(data:data, recordKey: "Error", dictionaryKeys: ["Code", "Message", "RequestId", "Resource"])
                let multipartResponse = xmlerror.go()
                print("response \(String(describing: multipartResponse))")
            print(error.localizedDescription)
            default:
            print("default")
            }
                
        }

        
        func createParts(_ asset: PHAsset,_ fileId: String) -> Promise<(String, [String:String])>  {
            return Promise { fulfill, reject in
                Utility.getURL(ofPhotoWith: asset) { url in
                    
                    let payloadFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    
                    var partETagArray = [String:String]()
                    var part = 0
                    
                    let fullSize = asset.size
                    
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
                                //partETagArray[part] = etag
                                //partETagArray.append(data.sha1)
                                let hash = data.sha256
                                let md5 = data.md5
                                
                                do {
                                    let file = try FileHandle(forWritingTo: payloadFileURL)
                                    file.write(data)
                                    file.truncateFile(atOffset: UInt64(bytes))
                                    file.closeFile()
                                } catch {
                                    reject (error)
                                }
                                
                                buildUploadPartRequest(hash: hash, md5: md5).then { data, response in
                                    print("looop")
                                    if let response = response as? HTTPURLResponse {
                                        print(response.allHeaderFields)
                                    }
                                    print(String(data:data!, encoding:.utf8))
                                    readBytes()
                                }.catch { error in
                                    print("readbytes \(error.localizedDescription)")
                                }
                                
                            } else {
                                do {
                                    try FileManager.default.removeItem(at: payloadFileURL)
                                } catch let error as NSError {
                                    os_log("error removing payloadFileURL. %@", log: .s3, type: .error, error.domain)
                                }
                                
                                inputStream.close()
                                
                                fulfill((fileId, partETagArray))
                            }
                        }
                        readBytes()
                        
                        
                        func buildUploadPartRequest(hash: String, md5: String) -> Promise<(Data?, URLResponse?)> {
                            let queryItemTokens = [URLQueryItem(name: "partNumber", value: String(part)),
                                                   URLQueryItem(name: "uploadId", value: fileId)]
                            
                            let uploadPart: Endpoint = {
                                var components = URLComponents()
                                components.host       = [self.bucket, self.hostName].joined(separator: ".")
                                components.path       = assetFileName.addingPrefixIfNeeded("/")
                                components.queryItems = queryItemTokens
                                return Endpoint(components: components)
                            }()
                            
                            guard let url2 = uploadPart.components.url else {
                                return Promise (ProviderError.preparationFailed)
                            }
                            
                            let date2      = Date().iso8601
                            let dateStamp2 = Date.getFormattedDate()
                            
                            let headers = [HTTPHeaders.contentLength:String(bytes),
                                           HTTPHeaders.expect:"100-continue",
                                           HTTPHeaders.contentSHA256:hash,
                                           HTTPHeaders.date: date2,
                                           HTTPHeaders.host: uploadPart.components.host!]
                                           //"content-md5":md5]
                            
                            var upRequest = URLRequest(url: url2)
                            
                            upRequest.httpMethod = HTTPMethod.put
                            upRequest.setValue(date2, forHTTPHeaderField: HTTPHeaders.date)
                            upRequest.setValue(String(bytes), forHTTPHeaderField: HTTPHeaders.contentLength)
                            upRequest.setValue(hash, forHTTPHeaderField: HTTPHeaders.contentSHA256)
                            //upRequest.setValue(md5,forHTTPHeaderField: "content-md5")
                            
                            var authHeader: String
                            
                            let authResult = self.getAuthorizationHeader(method: HTTPMethod.put, endpoint: uploadPart, headers: headers, hashedPayload: hash, date: date2, dateStamp: dateStamp2)
                            
                            switch authResult {
                            case .success(let result):
                                authHeader = result
                            case .failure(let error):
                                print("authheader \(error.localizedDescription)")
                                return Promise(error)
                            }
                            print("\(authHeader)")
                            print("\(url2.absoluteString)")
                            
                            upRequest.setValue(authHeader, forHTTPHeaderField: HTTPHeaders.authorization)
                            
                            upRequest.setValue("100-continue", forHTTPHeaderField: HTTPHeaders.expect)
                            
                            print(upRequest.allHTTPHeaderFields)
                            
                            return self.fetch(from: upRequest, from: payloadFileURL).catch { error in
                                switch error {
                                case ProviderError.validResponse(let data):
                                    print(String(data:data, encoding:.utf8)!)
                                    let xmlerror = XMLHelper(data:data, recordKey: "Error", dictionaryKeys: ["Code", "Message", "RequestId", "Resource"])
                                    let multipartResponse = xmlerror.go()
                                    print("response \(String(describing: multipartResponse))")
                                    print(error.localizedDescription)
                                default:
                                    print("default")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    //MARK: Codable
    
    enum CodingKeys: String, CodingKey {
        case accessKeyID
        case bucket
        case hostName
        case name
        case regionName
        case remoteFileList
        case secretAccessKey
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(accessKeyID, forKey: .accessKeyID)
        try container.encode(bucket, forKey: .bucket)
        try container.encode(hostName, forKey: .hostName)
        try container.encode(name, forKey: .name)
        try container.encode(regionName, forKey: .regionName)
        try container.encode(remoteFileList, forKey: .remoteFileList)
        try container.encode(secretAccessKey, forKey: .secretAccessKey)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        accessKeyID = try values.decode(String.self, forKey: .accessKeyID)
        bucket = try values.decode(String.self, forKey: .bucket)
        hostName = try values.decode(String.self, forKey: .hostName)
        name = try values.decode(String.self, forKey: .name)
        regionName = try values.decode(String.self, forKey: .regionName)
        remoteFileList = try values.decode([String:Data].self, forKey: .remoteFileList)
        secretAccessKey = try values.decode(String.self, forKey: .secretAccessKey)
    }
}

