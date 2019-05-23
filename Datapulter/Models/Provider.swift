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
import Promises

class Provider: NSObject, NSCoding  {
    
    //MARK: Properties
    
    var name: String 
    var backend: Site
    var remoteFileList: [String: Data]
    
    var cell: ProviderTableViewCell?

    var assetsToUpload = Set<PHAsset>()
    var largeFilePool = Set<PHAsset>()
    var uploadingAssets = [URLSessionTask: PHAsset]()
    var processingLargeFile: Bool = false
    
    var totalAssetsToUpload: Int = 0
    var totalAssetsUploaded: Int = 0
    
    enum Site {
        case Backblaze
        case S3
        case DatapulterManaged
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
        static let largeFiles = "largeFiles"
    }
    
    enum providerError: Error {
        case optionalBinding
        case connectionError
        case invalidResponse
        case invalidJson
        case preparationFailed
        case unhandledStatusCode
        case foundNil
        case largeFile
        var localizedDescription: String {
            switch self {
            case .optionalBinding: return "Optional binding"
            case .connectionError: return "Client side error"
            case .invalidResponse: return "Invalid response"
            case .invalidJson: return "Could not decode JSON"
            case .preparationFailed: return "Preparation failed"
            case .unhandledStatusCode: return "Status code not handled"
            case .foundNil: return "Found nil"
            case .largeFile: return "Large file encountered"
            }
        }
    }
    
    //MARK: Initialization
    
    init(name: String, backend: Site, remoteFileList: [String: Data]) {
        // Initialize stored properties.
        self.name = name
        self.backend = backend
        self.remoteFileList = remoteFileList
    }
    
    //MARK: Public methods
    
    public func authorize() -> Promise<Bool> {
        fatalError("Must Override")
    }
    
    public func decodeURLResponse(_ response: HTTPURLResponse,_ data: Data?,_ task: URLSessionTask,_ asset: PHAsset) {
        fatalError("Must Override")
    }
    
    public func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)> {
        fatalError("Must Override")
    }
    
    public func willDelete() {
        fatalError("Must Override")
    }
    
    public func updateRing() {
        let percentDone = CGFloat((totalAssetsUploaded * 100) / totalAssetsToUpload)
        
        DispatchQueue.main.async {
            self.cell?.ringView.startProgress(to: percentDone, duration: 0) {
                if (self.totalAssetsUploaded == self.totalAssetsToUpload) {
                    self.cell?.ringView.innerRingColor = .green
                    
                    self.hud("Done uploading!")
                    
                    self.totalAssetsToUpload = 0
                } else {
                    self.hud("\(self.totalAssetsUploaded) of \(self.totalAssetsToUpload)")
                }
            }
        }
    }
    
    public func hud(_ display: String) {
        DispatchQueue.main.async {
            self.cell?.hudLabel.text = display
        }
    }
    
    public func check() {
        fatalError("Must Override")
    }
    
    //MARK: NSCoding
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: PropertyKey.name)
        aCoder.encode(backend, forKey: PropertyKey.backend)
        aCoder.encode(remoteFileList, forKey: PropertyKey.remoteFileList)
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let name = aDecoder.decodeObject(forKey: PropertyKey.name) as? String else {
            os_log("Unable to decode the name for a Provider object.", log: OSLog.default, type: .debug)
            return nil
        }
        
        let backend = aDecoder.decodeObject(forKey: PropertyKey.backend) as! Site
        let remoteFileList = aDecoder.decodeObject(forKey: PropertyKey.remoteFileList) as! [String: Data]
        
        // Must call designated initializer.
        self.init(name: name, backend: backend, remoteFileList: remoteFileList)
    }
    
}
