//
//  S3.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/15/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Promises
import os.log

class S3: Provider {
    // sfo2.digitaloceanspaces.com
    // 7UMVJ6E6SAVLPCXF3C2B key_id
    // Ag6DmIiBeE1qs0mLqLL6LjgbhHaAM8IjD/88Hu8HwC4 key
    
    //MARK: Properties
    
    struct Defaults {
        static let dateFormat = "yyyyMMdd"
    }
    
    var accessKeyID: String
    var secretAccessKey: String
    
    //MARK: Types
    
    struct AuthorizationHeader {
        static let signatureVersion = "AWS4"
        static let signingAlgorithm = "HMAC-SHA256"
        static let service          = "s3/aws4_request"
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
    }
    
    //MARK: Initialization
    
    init(name: String, accessKeyID: String, secretAccessKey: String, remoteFileList: [String:Data]) {
        self.accessKeyID = accessKeyID
        self.secretAccessKey = secretAccessKey
        
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
         
         dateKey = HMAC-SHA256("AWS4" + ${SECRET_KEY}, date(format=YYYYMMDD))
         dateRegionKey = HMAC-SHA256(dateKey, ${REGION})
         dateRegionServiceKey = HMAC-SHA256(dateRegionKey, "s3")
         signingKey = HMAC-SHA256(dateRegionServiceKey, "aws4_request")
         
         signature = Hex(HMAC-SHA256(signingKey, stringToSign))
         
         HMAC(key, data)
         kDate = HMAC("AWS4" + kSecret, Date)
         kRegion = HMAC(kDate, Region)
         kService = HMAC(kRegion, Service)
         kSigning = HMAC(kService, "aws4_request")
         */
        let region = "us-east-1"
        
        //let endpoint = "https://" + region + ".digitaloceanspaces.com"
        //let signingKey = "something"
        
        // String.key(Data) -> Data
        
        let kSecret = "AWS4wJalrXUtnFEMI/K7MDENG+bPxRfiCYEXAMPLEKEY"
        //let str = String(describing: kSecret.cString(using: String.Encoding.utf8))
        let str = kSecret.data(using: .utf8)
        
        let kDate = "20120215".hmac_sha256(key: str!)
        print("kDate \(kDate.map { String(format: "%02x", $0) }.joined())")
        
        let kRegion = region.hmac_sha256(key: kDate)
        print("kRegion \(kRegion.map { String(format: "%02x", $0) }.joined())")
        
        let kService = "iam".hmac_sha256(key: kRegion)
        print("kService \(kService.map { String(format: "%02x", $0) }.joined())")
        let kSigning = "aws4_request".hmac_sha256(key: kService)
        
        
        print(kSigning.map { String(format: "%02x", $0) }.joined())
        
        
        /*
        let stringToSign = AuthorizationHeader.signatureVersion + "-" + AuthorizationHeader.signingAlgorithm + "\n"
            + Date().iso8601 + "\n"
            + Date.getFormattedDate(Defaults.dateFormat) + "/" + "region" + "/" + AuthorizationHeader.service + "\n"
    
        let signature = stringToSign.hmac_sha256(key: signingKey).sha256()*/
        
        return Promise(providerError.foundNil)
    }
    
    //MARK: Private methods
    
    //MARK: NSCoding
    
    override func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(accessKeyID, forKey: PropertyKey.accessKeyID)
        aCoder.encode(secretAccessKey, forKey: PropertyKey.secretAccessKey)
        aCoder.encode(remoteFileList, forKey: PropertyKey.remoteFileList)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // These are required. If we cannot decode, the initializer should fail.
        guard
            let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String,
            let accessKeyID = aDecoder.decodeObject(forKey: PropertyKey.accessKeyID) as? String,
            let secretAccessKey = aDecoder.decodeObject(forKey: PropertyKey.secretAccessKey) as? String,
            let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as? [String: Data]
            else
        {
            os_log("Unable to decode a S3 object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        // Must call designated initializer.
        self.init(name: name, accessKeyID: accessKeyID, secretAccessKey: secretAccessKey, remoteFileList: remoteFileList)
    }
}
