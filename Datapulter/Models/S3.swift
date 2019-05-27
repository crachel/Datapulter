//
//  S3.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/15/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//
/*
import UIKit
import Photos
import Promises
import os.log

class S3: Provider {
    
    //MARK: Properties
    
    struct Defaults {
        static let maxParts     = 10_000
        static let uploadCutoff = 50 * 1_000 * 1_000
        static let chunkSize    = 50 * 1_000 * 1_000
    }
    
    var accessKeyID: String
    var secretAccessKey: String
    var bucket: String
    var regionName: String
    var hostName: String
    
    //MARK: Types
    
    struct AuthorizationHeader {
        static let signatureVersion = "AWS4"
        static let signatureRequest = "aws4_request"
        static let signingAlgorithm = "AWS4-HMAC-SHA256"
        static let serviceName      = "s3"
    }
    
    struct HTTPHeaders {
        static let authorization = "Authorization"
        static let date          = "X-Amz-Date"
        static let mimeType      = "application/json"
        static let contentLength = "Content-Length"
        static let contentType   = "Content-Type"
        static let contentMD5    = "Content-MD5"
        static let expect        = "Expect" // 100-continue
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
    
    struct PropertyKey {
        static let accessKeyID     = "accessKeyID"
        static let secretAccessKey = "secretAccessKey"
        static let bucket          = "bucket"
        static let regionName      = "regionName"
        static let hostName        = "hostName"
    }
    
    //MARK: Initialization
    
    init(name: String, accessKeyID: String, secretAccessKey: String, bucket: String, regionName: String, hostName: String, remoteFileList: [String:Data]) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.bucket = bucket
        self.regionName = regionName
        self.hostName = hostName
        
        super.init(name: name, backend: .S3, remoteFileList: remoteFileList)
    }
    
    //MARK: Public methods
    
    override func authorize() -> Promise<Bool> {
        return Promise(false)
    }
    
    override func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)> {
        let putObject: Endpoint = {
            var components = URLComponents()
            components.scheme = "https"
            components.host   = bucket + "." + hostName
            return Endpoint(components: components)
        }()
        
        let date      = Date().iso8601
        let dateStamp = Date.getFormattedDate()
        
        func getSigningKey(_ kSecret: Data) -> Data {
            let kDate    = dateStamp.hmac_sha256(key: kSecret)
            let kRegion  = regionName.hmac_sha256(key: kDate)
            let kService = AuthorizationHeader.serviceName.hmac_sha256(key: kRegion)
            let kSigning = AuthorizationHeader.signatureRequest.hmac_sha256(key: kService)
            
            return kSigning
        }
        
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
            
            return Promise(providerError.largeFile) //need to return here so we don't try to process large file anyway
        }

        return Promise { fulfill, reject in
            guard let kSecret = (AuthorizationHeader.signatureVersion + self.secretAccessKey).data(using: .utf8) else {
                throw (providerError.foundNil)
            }
            
            let kSigning = getSigningKey(kSecret)
            
            guard let url = URL(string: putObject.components.string! + "/" + asset.percentEncodedFilename!) else {
                throw (providerError.preparationFailed)
            }
            
            guard let fileName = asset.percentEncodedFilename else {
                throw (providerError.foundNil)
            }
            
            var urlRequest = URLRequest(url: url)
            
            urlRequest.httpMethod = HTTPMethod.put
            urlRequest.setValue(String(asset.size), forHTTPHeaderField: HTTPHeaders.contentLength)
            urlRequest.setValue(date, forHTTPHeaderField: HTTPHeaders.date)
            urlRequest.setValue("100-continue", forHTTPHeaderField: "Expect")
    
            Utility.getData(from: asset) { data, _ in
                let sha256hash = data.sha256
                
                urlRequest.setValue(sha256hash, forHTTPHeaderField: HTTPHeaders.contentSHA256)
                
                if asset.creationDate != nil {
                    
                }
                
                let unixCreationDate = asset.creationDate?.millisecondsSince1970
                
                urlRequest.setValue((unixCreationDate?.description), forHTTPHeaderField: HTTPHeaders.modified)
                    
                //print("asset \(asset)")
                
                //asset.mediaType
                //asset.originalFilename
            
                let canonicalRequest =
                    "PUT\n" +
                    "/" + fileName + "\n" +
                    "\n" +
                    "content-length:\(String(asset.size))\n" +
                    "expect:100-continue\n" +
                    "host:\(putObject.components.host!)\n" +
                    "x-amz-content-sha256:\(sha256hash)\n" +
                    "x-amz-date:\(date)\n" +
                    HTTPHeaders.modified + ":\(String(unixCreationDate!))\n\n" +
                    "content-length;expect;host;x-amz-content-sha256;x-amz-date;\(HTTPHeaders.modified)\n" +
                    sha256hash
                
                //print("canrequest \(canonicalRequest)")
                
                let stringToSign = "AWS4-HMAC-SHA256" + "\n" +
                    date + "\n" +
                    "\(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest)" + "\n" +
                    canonicalRequest.data(using: .utf8)!.sha256
                
                //print("stringtosign \(stringToSign)")
                
                let signature = stringToSign.hmac_sha256(key: kSigning)
                
                let header = "AWS4-HMAC-SHA256 Credential=\(self.accessKeyID)/\(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest),SignedHeaders=host;expect;content-length;x-amz-content-sha256;x-amz-date;\(HTTPHeaders.modified),Signature=\(signature.hex)"
                
                urlRequest.setValue(header, forHTTPHeaderField: HTTPHeaders.authorization)
                
                fulfill((urlRequest, data))
            }
        }
    }
    
    override func decodeURLResponse(_ response: HTTPURLResponse,_ data: Data?,_ task: URLSessionTask,_ asset: PHAsset) {
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
    
    override func willDelete() {
        print("willoverride")
    }
    
    //MARK: Private methods
    
    private func processLargeFile(_ asset: PHAsset) throws {
        
        let putObject: Endpoint = {
            var components = URLComponents()
            components.scheme = "https"
            components.host   = bucket + "." + hostName
            return Endpoint(components: components)
        }()
        
        let date      = Date().iso8601
        let dateStamp = Date.getFormattedDate()
        
        let xml = """
            <?xml version="1.0" encoding="UTF-8"?>
            <InitiateMultipartUploadResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
              <Bucket>example-bucket</Bucket>
              <Key>example-object</Key>
              <UploadId>VXBsb2FkIElEIGZvciA2aWWpbmcncyBteS1tb3ZpZS5tMnRzIHVwbG9hZA</UploadId>
            </InitiateMultipartUploadResult>
            """.data(using: .utf8)!
        
        guard let fileName = asset.percentEncodedFilename else {
            throw (providerError.foundNil)
        }
        
        func getSigningKey(_ kSecret: Data) -> Data {
            let kDate    = dateStamp.hmac_sha256(key: kSecret)
            let kRegion  = regionName.hmac_sha256(key: kDate)
            let kService = AuthorizationHeader.serviceName.hmac_sha256(key: kRegion)
            let kSigning = AuthorizationHeader.signatureRequest.hmac_sha256(key: kService)
            
            return kSigning
        }
        
        let unixCreationDate = asset.creationDate?.millisecondsSince1970
        
        guard let kSecret = (AuthorizationHeader.signatureVersion + self.secretAccessKey).data(using: .utf8) else {
            throw (providerError.foundNil)
        }
        
        guard let url = URL(string: putObject.components.string! + "/" + asset.percentEncodedFilename! + "?uploads") else {
            throw (providerError.preparationFailed)
        }
        
        let kSigning = getSigningKey(kSecret)
        
        let canonicalRequest =
            "POST\n" +
            "/" + fileName + "\n" +
            "uploads\n" +
            "expect:100-continue\n" +
            "host:\(putObject.components.host!)\n" +
            "x-amz-date:\(date)\n" +
            HTTPHeaders.modified + ":\(String(unixCreationDate!))\n\n" +
            "expect;host;x-amz-date;\(HTTPHeaders.modified)\n"
        
        
        let stringToSign = "AWS4-HMAC-SHA256" + "\n" +
            date + "\n" +
            "\(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest)" + "\n" +
            canonicalRequest.data(using: .utf8)!.sha256
        
        //print("stringtosign \(stringToSign)")
        
        let signature = stringToSign.hmac_sha256(key: kSigning)
        
        let header = "AWS4-HMAC-SHA256 Credential=\(self.accessKeyID)/\(dateStamp)/\(self.regionName)/\(AuthorizationHeader.serviceName)/\(AuthorizationHeader.signatureRequest),SignedHeaders=host;expect;x-amz-date;\(HTTPHeaders.modified),Signature=\(signature.hex)"
        
        print(header)
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = HTTPMethod.put
        urlRequest.setValue(String(asset.size), forHTTPHeaderField: HTTPHeaders.contentLength)
        urlRequest.setValue(date, forHTTPHeaderField: HTTPHeaders.date)
        urlRequest.setValue("100-continue", forHTTPHeaderField: "Expect")
        
        let xmlHelper = XMLHelper(data: xml,
                                  recordKey: "InitiateMultipartUploadResult",
                                  dictionaryKeys: ["Bucket", "Key", "UploadId"])
        
        let multipartResponse = xmlHelper.go()
        
        
        /*
        func createParts(_ asset: PHAsset,_ fileId: String) {
            return Promise { fulfill, reject in
                Utility.getURL(ofPhotoWith: asset) { url in
                    
                    let payloadFileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                    
                    var partETagArray = [String:String]()
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
                                    os_log("error removing payloadFileURL. %@", log: .s3, type: .error, error.domain)
                                }
                                
                                inputStream.close()
                                
                                fulfill((fileId, partSha1Array))
                            }
                        }
                        readBytes()
                        
                        func buildUploadPartRequest() -> Promise<(Data?, URLResponse?)> {
                            
                        }
                        
                        func uploadPart(_ result: GetUploadPartURLResponse,_ dataCount: Int,_ url: URL,_ partNumber: Int,_ sha1: String) -> Promise<(Data?, URLResponse?)> {
                            
                        }
                    }
                }
            }
        }*/
    }
    
    //MARK: NSCoding
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(accessKeyID, forKey: PropertyKey.accessKeyID)
        aCoder.encode(secretAccessKey, forKey: PropertyKey.secretAccessKey)
        aCoder.encode(bucket, forKey: PropertyKey.bucket)
        aCoder.encode(regionName, forKey: PropertyKey.regionName)
        aCoder.encode(hostName, forKey: PropertyKey.hostName)
        aCoder.encode(remoteFileList, forKey: PropertyKey.remoteFileList)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // These are required. If we cannot decode, the initializer should fail.
        guard
            let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String,
            let accessKeyID = aDecoder.decodeObject(forKey: PropertyKey.accessKeyID) as? String,
            let secretAccessKey = aDecoder.decodeObject(forKey: PropertyKey.secretAccessKey) as? String,
            let bucket = aDecoder.decodeObject(forKey: PropertyKey.bucket) as? String,
            let regionName = aDecoder.decodeObject(forKey: PropertyKey.regionName) as? String,
            let hostName = aDecoder.decodeObject(forKey: PropertyKey.hostName) as? String,
            let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as? [String: Data]
            else
        {
            os_log("Unable to decode a S3 object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        // Must call designated initializer.
        self.init(name: name, accessKeyID: accessKeyID, secretAccessKey: secretAccessKey, bucket: bucket, regionName: regionName, hostName: hostName, remoteFileList: remoteFileList)
    }
}
*/
