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
    
    public func sign() {
        print(Date.getFormattedDate(dateFormat: Defaults.dateFormat))
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
