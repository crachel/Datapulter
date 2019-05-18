//
//  S3.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/15/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos
import Promises
import os.log

class S3: Provider {
    // sfo2.digitaloceanspaces.com
    // 7UMVJ6E6SAVLPCXF3C2B key_id
    // Ag6DmIiBeE1qs0mLqLL6LjgbhHaAM8IjD/88Hu8HwC4 key
   
    // s3
    // AKIAZ46WPMYAAYVDOW5H key_id
    // QiMPRgD7o6xQdCQH65UTTBppvtTWcxyA2sZdz6uX key
    
    //MARK: Properties
    
    struct Defaults {
        static let dateFormat = "yyyyMMdd"
    }
    
    var accessKeyID: String
    var secretAccessKey: String
    var region: String
    
    //MARK: Types
    
    struct AuthorizationHeader {
        static let signatureVersion = "AWS4"
        static let signatureRequest = "aws4_request"
        static let signingAlgorithm = "HMAC-SHA256"
        static let service          = "s3"
        static let date             = Date.getFormattedDate(Defaults.dateFormat)
    }
    
    struct HTTPHeaders {
        static let authorization = "Authorization"
        static let date          = "Date"
        static let mimeType      = "application/json"
        static let contentLength = "Content-Length"
    }
    
    struct PropertyKey {
        static let accessKeyID     = "accessKeyID"
        static let secretAccessKey = "secretAccessKey"
        static let region          = "region"
    }
    
    //MARK: Initialization
    
    init(name: String, accessKeyID: String, secretAccessKey: String, region: String, remoteFileList: [String:Data]) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        self.region = region
        
        super.init(name: name, backend: .S3, remoteFileList: remoteFileList)
    }
    
    //MARK: Public methods
    
    override func authorizeAccount() -> Promise<(Data?, URLResponse?)> {
        /*
         canonicalRequest = `
         ${HTTPMethod}\n
         ${canonicalURI}\n
         ${canonicalQueryString}\n
         ${canonicalHeaders}\n
         ${signedHeaders}\n
         ${hashedPayload}
         `
         
         stringToSign = "AWS4-HMAC-SHA256" + "\n" +
         date(format=ISO08601) + "\n" +
         date(format=YYYYMMDD) + "/" + ${REGION} + "/" + "s3/aws4_request" + "\n" +
         Hex(SHA256Hash(canonicalRequest))
         
         */
        
        guard let kSecret = (AuthorizationHeader.signatureVersion + secretAccessKey).data(using: .utf8) else {
            return Promise(providerError.foundNil)
        }
        
        let kDate    = AuthorizationHeader.date.hmac_sha256(key: kSecret)
        let kRegion  = region.hmac_sha256(key: kDate)
        let kService = AuthorizationHeader.service.hmac_sha256(key: kRegion)
        let kSigning = AuthorizationHeader.signatureRequest.hmac_sha256(key: kService)
        
        print(kSigning.hex)
        
        
        /*
        let stringToSign = AuthorizationHeader.signatureVersion + "-" + AuthorizationHeader.signingAlgorithm + "\n"
            + Date().iso8601 + "\n"
            + Date.getFormattedDate(Defaults.dateFormat) + "/" + "region" + "/" + AuthorizationHeader.service + "\n"
    
        let signature = stringToSign.hmac_sha256(key: signingKey).sha256()*/
        
        return Promise(providerError.foundNil)
    }
    
    override func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)> {
        //sfo2.digitaloceanspaces.com
        guard let url = URL(string: "http://sfo2.digitaloceanspaces.com") else {
            return Promise(providerError.preparationFailed)
        }
        
        var urlRequest = URLRequest(url: url)
        
        urlRequest.httpMethod = HTTPMethod.put
        
        let canonicalRequest = "PUT\n" +
            asset.percentEncodedFilename! + "\n\n"
        
        let stringToSign = ""
        
        let signingKey = ""
        
        // let signature = Hex(HMAC(signingKey, stringToSign))
        return Promise(providerError.foundNil)
    }
    
    //MARK: Private methods
    
    //MARK: NSCoding
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(accessKeyID, forKey: PropertyKey.accessKeyID)
        aCoder.encode(secretAccessKey, forKey: PropertyKey.secretAccessKey)
        aCoder.encode(region, forKey: PropertyKey.region)
        aCoder.encode(remoteFileList, forKey: PropertyKey.remoteFileList)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // These are required. If we cannot decode, the initializer should fail.
        guard
            let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String,
            let accessKeyID = aDecoder.decodeObject(forKey: PropertyKey.accessKeyID) as? String,
            let secretAccessKey = aDecoder.decodeObject(forKey: PropertyKey.secretAccessKey) as? String,
            let region = aDecoder.decodeObject(forKey: PropertyKey.region) as? String,
            let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as? [String: Data]
            else
        {
            os_log("Unable to decode a S3 object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        // Must call designated initializer.
        self.init(name: name, accessKeyID: accessKeyID, secretAccessKey: secretAccessKey, region: region, remoteFileList: remoteFileList)
    }
}
