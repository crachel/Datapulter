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
        static let uploadCutoff = 25 * 1_000 * 1_000
        static let chunkSize    = 25 * 1_000 * 1_000
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
    var port: Int = 443 //
    var regionName: String
    var remoteFileList: [String: Data]
    var secretAccessKey: String
    var filePrefix: String?
    var storageClass: String = "STANDARD"
    var useVirtual: Bool = true //
    
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
        static let typeXml       = "application/xml"
        static let storageClass  = "x-amz-storage-class"
    }
    
    struct File: Codable {
        var accessKeyID: String
        var bucket: String
        var contentLength: Int64
        var contentSha256: String?
        var contentType: String
        var fileName: String
        var uploadTimestamp: Int64
    }
    
    //MARK: Initialization
    
    init(name: String, accessKeyID: String, secretAccessKey: String, bucket: String, regionName: String, hostName: String, remoteFileList: [String:Data], filePrefix: String?, storageClass: String, useVirtual: Bool, port: Int) {
        self.accessKeyID = accessKeyID
        self.bucket = bucket
        self.hostName = hostName
        self.name = name
        self.port = port
        self.regionName = regionName
        self.remoteFileList = remoteFileList
        self.secretAccessKey = secretAccessKey
        self.filePrefix = filePrefix
        self.storageClass = storageClass
        self.useVirtual = useVirtual
    }
    
    //MARK: Public methods
    
    func authorize() -> Promise<Bool> {
        return Promise(true)
    }
    
    func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)> {
        
        guard var assetFileName = asset.originalFilename else {
            return Promise(ProviderError.foundNil)
        }
        
        if let prefix = filePrefix {
            assetFileName = prefix.addingSuffixIfNeeded("/") + assetFileName
        }
        
        if(!useVirtual) {
            assetFileName = bucket.addingSuffixIfNeeded("/") + assetFileName
        }
        
        let putObject: Endpoint = {
            var components = URLComponents()
            if (useVirtual) {
                components.host = [bucket, hostName].joined(separator: ".")
            } else {
                components.scheme = "http"
                components.host = hostName
                components.port = port
            }
            components.path = assetFileName.addingPrefixIfNeeded("/")
            return Endpoint(components: components, method: HTTPMethod.put)
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
                    os_log("processingLargeFile %@", log: .s3, type: .error, error.localizedDescription)
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
        
        return Promise { fulfill, reject in
            Utility.getData(from: asset) { data, _ in
                
                let hashedPayload = data.sha256
                
                var urlRequest = URLRequest(url: url)
                
                urlRequest.httpMethod = putObject.method
                urlRequest.setValue(date, forHTTPHeaderField: HTTPHeaders.date)
                urlRequest.setValue("100-continue", forHTTPHeaderField: HTTPHeaders.expect)
                
                let unixCreationDate = asset.creationDate?.millisecondsSince1970
                
                urlRequest.setValue((unixCreationDate?.description), forHTTPHeaderField: HTTPHeaders.modified)
                
                urlRequest.setValue(hashedPayload, forHTTPHeaderField: HTTPHeaders.contentSHA256)
                urlRequest.setValue(String(data.count), forHTTPHeaderField: HTTPHeaders.contentLength)
                urlRequest.setValue(self.storageClass, forHTTPHeaderField: HTTPHeaders.storageClass)
   
                var headers = [HTTPHeaders.contentLength: String(data.count),
                               HTTPHeaders.expect:"100-continue",
                               //HTTPHeaders.host:[fullHost, String(putObject.components.port ?? 443)].joined(separator: ":")
                               //HTTPHeaders.host:fullHost,
                               HTTPHeaders.contentSHA256:hashedPayload,
                               HTTPHeaders.date:date,
                               HTTPHeaders.modified:String(unixCreationDate!),
                               HTTPHeaders.storageClass:self.storageClass]
                
                if (self.useVirtual) {
                    headers[HTTPHeaders.host] = fullHost
                } else {
                    headers[HTTPHeaders.host] = [fullHost, String(putObject.components.port ?? 443)].joined(separator: ":")
                }
                
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
                    if let data = data {
                        print(String(data:data, encoding:.utf8))
                        //<Code>SignatureDoesNotMatch</Code>
                    }
                    // parse xml and figure out what happened. decide course of action
                    assetsToUpload.insert(asset)
                    
                    AutoUpload.shared.initiate(1, self)
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
        
        let canonicalQueryString = endpoint.components.queryItems?.compactMap({ queryItem -> String in
            return "\(queryItem.name)=\(queryItem.value ?? "")"
        }).joined(separator: "&") ?? ""
        
        let canonicalRequest = """
        \(method)
        \(canonicalURI)
        \(canonicalQueryString)
        \(canonicalHeaders)
        
        \(signedHeaders)
        \(hashedPayload)
        """
        
        print(canonicalRequest)
        
        let stringToSign = """
        AWS4-HMAC-SHA256
        \(date)
        \(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest)
        \(canonicalRequest.data(using: .utf8)!.sha256)
        """
        
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
        
        guard var assetFileName = asset.originalFilename else {
            throw (ProviderError.foundNil)
        }
        
        if let prefix = filePrefix {
            assetFileName = prefix.addingSuffixIfNeeded("/") + assetFileName
        }
        
        if(!useVirtual) {
            assetFileName = bucket.addingSuffixIfNeeded("/") + assetFileName
        }
        
        
        func finishLargeFile(uploadId: String, partETagArray: [String:String], size: Int64) -> Promise<(Data?, URLResponse?)> {
            var post: String = "<CompleteMultipartUpload>"
            
            for (key, value) in partETagArray.sorted(by: { Int($0.key) ?? 0 < Int($1.key) ?? 0 }) {
                let node: String = """
                \n<Part>
                <PartNumber>\(key)</PartNumber>
                <ETag>\(value)</ETag>
                </Part>
                """
                post.append(node)
            }
            
            post.append("\n</CompleteMultipartUpload>")
            
            print(post)
            
            let queryUploadId = URLQueryItem(name: "uploadId", value: uploadId)
            
            let completeMulti: Endpoint = {
                var components = URLComponents()
                //components.host       = [bucket, hostName].joined(separator: ".")
                if (useVirtual) {
                    components.host = [bucket, hostName].joined(separator: ".")
                } else {
                    components.scheme = "http"
                    components.host = hostName
                    components.port = port
                }
                components.path       = assetFileName.addingPrefixIfNeeded("/")
                components.queryItems = [queryUploadId]
                return Endpoint(components: components, method: HTTPMethod.post)
            }()
            
            let completeDate      = Date().iso8601
            let completeDateStamp = Date.getFormattedDate()
            
            guard let completePayload = post.data(using: .utf8) else {
                os_log("finishLargeFile could not convert payload to data", log: .s3, type: .error)
                return Promise(ProviderError.foundNil)
            }
            
            let completeHash = completePayload.sha256
            
            let postSize = post.data(using: .utf8)!.count
            
            guard let completeUrl = completeMulti.components.url else {
                os_log("finishLargeFile bad url", log: .s3, type: .error)
                return Promise(ProviderError.foundNil)
            }
            
            var completeRequest = URLRequest(url: completeUrl)
            
            completeRequest.httpMethod = HTTPMethod.post
            completeRequest.setValue(completeDate, forHTTPHeaderField: HTTPHeaders.date)
            completeRequest.setValue(String(postSize), forHTTPHeaderField: HTTPHeaders.contentLength)
            completeRequest.setValue(completeHash, forHTTPHeaderField: HTTPHeaders.contentSHA256)
            completeRequest.setValue(HTTPHeaders.typeXml, forHTTPHeaderField: HTTPHeaders.contentType)
            
            var completeHeaders = [HTTPHeaders.contentLength:String(postSize),
                                   HTTPHeaders.date: completeDate,
                                   HTTPHeaders.contentSHA256: completeHash,
                                   //HTTPHeaders.host: completeMulti.components.host!,
                                   HTTPHeaders.contentType:HTTPHeaders.typeXml]
            
            if (self.useVirtual) {
                completeHeaders[HTTPHeaders.host] = completeMulti.components.host!
            } else {
                completeHeaders[HTTPHeaders.host] = [completeMulti.components.host!, String(completeMulti.components.port ?? 443)].joined(separator: ":")
            }
            
            let completeResult = getAuthorizationHeader(method: HTTPMethod.post, endpoint: completeMulti, headers: completeHeaders, hashedPayload: completeHash, date: completeDate, dateStamp: completeDateStamp)
            
            var completeAuthHeader: String
            
            switch completeResult {
            case .success(let result):
                completeAuthHeader = result
            case .failure(let error):
                os_log("finishLargeFile could not getAuthorizationHeader", log: .s3, type: .error)
                return Promise(error)
            }
            
            completeRequest.setValue(completeAuthHeader, forHTTPHeaderField: HTTPHeaders.authorization)
            completeRequest.httpBody = completePayload
            
            return self.fetch(with: completeRequest)
        }
        
        let queryItemToken = URLQueryItem(name: "uploads", value: nil)
        
        let putObject: Endpoint = {
            var components = URLComponents()
            //components.host       = [bucket, hostName].joined(separator: ".")
            if (useVirtual) {
                components.host = [bucket, hostName].joined(separator: ".")
            } else {
                components.scheme = "http"
                components.host = hostName
                components.port = port
            }
            components.path       = assetFileName.addingPrefixIfNeeded("/")
            components.queryItems = [queryItemToken]
            return Endpoint(components: components, method: HTTPMethod.post)
        }()
        
        let date      = Date().iso8601
        let dateStamp = Date.getFormattedDate()
        
        let hashedPayload = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
        
        guard let fullHost = putObject.components.host else {
            throw (ProviderError.preparationFailed)
        }
        
        var headers = [//HTTPHeaders.host: fullHost,
                       HTTPHeaders.contentSHA256: hashedPayload,
                       HTTPHeaders.date: date,
                       HTTPHeaders.storageClass:storageClass]
        
        if (self.useVirtual) {
            headers[HTTPHeaders.host] = fullHost
        } else {
            headers[HTTPHeaders.host] = [fullHost, String(putObject.components.port ?? 443)].joined(separator: ":")
        }
        
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
        urlRequest.setValue(storageClass, forHTTPHeaderField: HTTPHeaders.storageClass)
        
        fetch(with: urlRequest).then { data, _ in
            Utility.objectIsType(object: data, someObjectOfType: Data.self)
        }.then { data in
            XMLHelper(data:data, recordKey: "InitiateMultipartUploadResult", dictionaryKeys: ["Bucket", "Key", "UploadId"]).go()
        }.then { responseDictionary in
            createParts(asset, (responseDictionary?.first!["UploadId"])!)
        }.then { fileId, partETagArray in
            finishLargeFile(uploadId: fileId, partETagArray: partETagArray, size: asset.size)
        }.then { data, response in
            //self.finishUploadOperation(asset.localIdentifier, data)
            if let response = response as? HTTPURLResponse {
                if(response.statusCode == 200) {
                    let data = try JSONSerialization.data(withJSONObject: response.allHeaderFields, options: [])
                    self.remoteFileList[asset.localIdentifier] = data
                    
                    self.totalAssetsUploaded += 1
                    
                    self.updateRing()
                    
                    ProviderManager.shared.saveProviders()
                }
            }
            
            
            if (self.largeFilePool.isEmpty) {
                self.processingLargeFile = false // ends here
            } else {
                if let newAsset = self.largeFilePool.popFirst() {
                    try self.processLargeFile(newAsset)
                } else {
                    throw ProviderError.foundNil
                }
            }
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
                                let hash = data.sha256
                                
                                do {
                                    let file = try FileHandle(forWritingTo: payloadFileURL)
                                    file.write(data)
                                    file.truncateFile(atOffset: UInt64(bytes))
                                    file.closeFile()
                                } catch {
                                    reject (error)
                                }
                                
                                buildUploadPartRequest(hash: hash).then { data, response in
                                    if let response = response as? HTTPURLResponse {
                                        partETagArray[String(part)] = response.allHeaderFields["Etag"] as? String
                                        //partETagArray[part] = response.allHeaderFields["Etag"] as? String
                                    }
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
                        
                        
                        func buildUploadPartRequest(hash: String) -> Promise<(Data?, URLResponse?)> {
                            let queryItemTokens = [URLQueryItem(name: "partNumber", value: String(part)),
                                                   URLQueryItem(name: "uploadId", value: fileId)]
                            
                            let uploadPart: Endpoint = {
                                var components = URLComponents()
                                //components.host       = [self.bucket, self.hostName].joined(separator: ".")
                                if (self.useVirtual) {
                                    components.host = [self.bucket, self.hostName].joined(separator: ".")
                                } else {
                                    components.scheme = "http"
                                    components.host = self.hostName
                                    components.port = self.port
                                }
                                components.path       = assetFileName.addingPrefixIfNeeded("/")
                                components.queryItems = queryItemTokens
                                return Endpoint(components: components)
                            }()
                            
                            guard let url2 = uploadPart.components.url else {
                                return Promise (ProviderError.preparationFailed)
                            }
                            
                            let date2      = Date().iso8601
                            let dateStamp2 = Date.getFormattedDate()
                            
                            var headers = [HTTPHeaders.contentLength:String(bytes),
                                           HTTPHeaders.expect:"100-continue",
                                           HTTPHeaders.contentSHA256:hash,
                                           HTTPHeaders.date: date2]
                                           //HTTPHeaders.host: uploadPart.components.host!]
                            
                            if (self.useVirtual) {
                                headers[HTTPHeaders.host] = uploadPart.components.host!
                            } else {
                                headers[HTTPHeaders.host] = [uploadPart.components.host!, String(uploadPart.components.port ?? 443)].joined(separator: ":")
                            }
                            
                            var upRequest = URLRequest(url: url2)
                            
                            upRequest.httpMethod = HTTPMethod.put
                            upRequest.setValue(date2, forHTTPHeaderField: HTTPHeaders.date)
                            upRequest.setValue(String(bytes), forHTTPHeaderField: HTTPHeaders.contentLength)
                            upRequest.setValue(hash, forHTTPHeaderField: HTTPHeaders.contentSHA256)
                            
                            
                            var authHeader: String
                            
                            let authResult = self.getAuthorizationHeader(method: HTTPMethod.put, endpoint: uploadPart, headers: headers, hashedPayload: hash, date: date2, dateStamp: dateStamp2)
                            
                            switch authResult {
                            case .success(let result):
                                authHeader = result
                            case .failure(let error):
                                print("authheader \(error.localizedDescription)")
                                return Promise(error)
                            }
                            //print("\(authHeader)")
                            //print("\(url2.absoluteString)")
                            
                            upRequest.setValue(authHeader, forHTTPHeaderField: HTTPHeaders.authorization)
                            
                            upRequest.setValue("100-continue", forHTTPHeaderField: HTTPHeaders.expect)
                            
                            return self.fetch(with: upRequest, fromFile: payloadFileURL).recover { error -> Promise<(Data?, URLResponse?)> in
                                switch error {
                                case ProviderError.validResponse(let data):
                                    print(String(data:data, encoding:.utf8)!)
                                    let xmlerror = XMLHelper(data:data, recordKey: "Error", dictionaryKeys: ["Code", "Message", "RequestId", "Resource"])
                                    let multipartResponse = xmlerror.go()
                                    print("response \(String(describing: multipartResponse))")
                                    print(error.localizedDescription)
                                    return buildUploadPartRequest(hash: hash)
                                default:
                                    return Promise(error)
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
        case filePrefix
        case hostName
        case name
        case port
        case regionName
        case remoteFileList
        case secretAccessKey
        case storageClass
        case useVirtual
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(accessKeyID, forKey: .accessKeyID)
        try container.encode(bucket, forKey: .bucket)
        try container.encode(filePrefix, forKey: .filePrefix)
        try container.encode(hostName, forKey: .hostName)
        try container.encode(name, forKey: .name)
        try container.encode(port, forKey: .port)
        try container.encode(regionName, forKey: .regionName)
        try container.encode(remoteFileList, forKey: .remoteFileList)
        try container.encode(secretAccessKey, forKey: .secretAccessKey)
        try container.encode(storageClass, forKey: .storageClass)
        try container.encode(useVirtual, forKey: .useVirtual)
    }
    
    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        
        accessKeyID = try values.decode(String.self, forKey: .accessKeyID)
        bucket = try values.decode(String.self, forKey: .bucket)
        filePrefix = try values.decode(String.self, forKey: .filePrefix)
        hostName = try values.decode(String.self, forKey: .hostName)
        name = try values.decode(String.self, forKey: .name)
        port = try values.decode(Int.self, forKey: .port)
        regionName = try values.decode(String.self, forKey: .regionName)
        remoteFileList = try values.decode([String:Data].self, forKey: .remoteFileList)
        secretAccessKey = try values.decode(String.self, forKey: .secretAccessKey)
        storageClass = try values.decode(String.self, forKey: .storageClass)
        useVirtual = try values.decode(Bool.self, forKey: .useVirtual)
    }
}

