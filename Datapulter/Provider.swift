//
//  Provider.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Photos
import os.log

class Provider: NSObject, NSCoding {
    
    //MARK: Properties
    
    var name: String 
    var backend: Site
    var remoteFileList: [PHAsset: [String:Any]]
    var assetsToUpload = Set<PHAsset>() {
        didSet {
            // possibly do something here
        }
    }
    var uploadQueue: [URLRequest: URL]?
    var innerRing: UIColor
    var cell: ProviderTableViewCell?
    
    enum Site {
        case Backblaze
        case Amazon
        case DigitalOcean
    }
    
    //MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("providers")
    
    //MARK: Types
    
    struct PropertyKey {
        static let name = "name"
        static let backend = "backend"
        static let remoteFileList = "remoteFileList"
        static let assetsToUpload = "assetsToUpload"
        static let uploadQueue = "uploadQueue"
    }
    
    enum providerError: String, Error {
        case optionalBinding
    }
    
    //MARK: Initialization
    
    init(name: String, backend: Site) {
        // Initialize stored properties.
        self.name = name
        self.backend = backend
        self.innerRing = .blue
        self.remoteFileList = [:]
        self.assetsToUpload = []
        self.uploadQueue = [:]
    }
    
    init(name: String, backend: Site, remoteFileList: [PHAsset: [String:Any]], assetsToUpload: Set<PHAsset>, uploadQueue: [URLRequest: URL]) {
        // Initialize stored properties.
        self.name = name
        self.backend = backend
        self.innerRing = .blue
        self.remoteFileList = remoteFileList
        self.assetsToUpload = assetsToUpload
        self.uploadQueue = uploadQueue
    }
    
    //MARK: NSCoding
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(backend, forKey: PropertyKey.backend)
        aCoder.encode(remoteFileList, forKey: PropertyKey.backend)
        aCoder.encode(assetsToUpload, forKey: PropertyKey.assetsToUpload)
        aCoder.encode(uploadQueue, forKey: PropertyKey.uploadQueue)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else {
            os_log("Unable to decode the name for a Provider object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let backend = aDecoder.decodeObject(forKey: PropertyKey.backend) as! Site
        let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as! [PHAsset: [String:Any]]
        let assetsToUpload = aDecoder.decodeObject(forKey: PropertyKey.assetsToUpload) as! Set<PHAsset>
        let uploadQueue = aDecoder.decodeObject(forKey: PropertyKey.uploadQueue) as! [URLRequest: URL]
        
        // Must call designated initializer.
        self.init(name: name, backend: backend, remoteFileList: remoteFileList, assetsToUpload: assetsToUpload, uploadQueue: uploadQueue)
    }
    
}
