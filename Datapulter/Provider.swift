//
//  Provider.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log

class Provider: NSObject, NSCoding {
    
    //MARK: Properties
    
    var name: String
    var innerRing: UIColor
    
    var Account: String?
    var Key: String?
    var Endpoint: String?
    var Versions: Bool?
    var HardDelete: Bool?
    var UploadCutoff: Int64?
    var ChunkSize: Int64?
    
    //MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("providers")
    
    //MARK: Types
    
    struct PropertyKey {
        static let name = "name"
    }
    
    //MARK: Initialization
    
    init(name: String) {
        // Initialize stored properties.
        self.name = name
        self.innerRing = .green
    }
    
    init(name: String, Account: String, Key: String, Versions: Bool, HardDelete: Bool, UploadCutoff: Int64, ChunkSize: Int64) {
        self.name = name
        self.Account = Account
        self.Key = Key
        self.Versions = Versions
        self.HardDelete = HardDelete
        self.UploadCutoff = UploadCutoff
        self.ChunkSize = ChunkSize
        self.innerRing = .green
    }
    
    //MARK: NSCoding
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else {
            os_log("Unable to decode the name for a Provider object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        // Must call designated initializer.
        self.init(name: name)
    }
    
}
