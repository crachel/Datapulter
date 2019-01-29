//
//  AutoUpload.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/13/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Photos
import UICircularProgressRing

class AutoUpload {
    
    //MARK: Properties
    static let shared = AutoUpload()
    
    typealias TaskId = Int
    
    var assets: PHFetchResult<PHAsset>
    
    var providers = [Provider]()
    var uploadingAssets: [TaskId: PHAsset]? // URLSessionTask associated with each PHAsset
    
    var assetsToUploadCount: Int?

    //MARK: Initialization
    
    private init() {
        
        assets = Utility.getCameraRollAssets()
        
    }
 
    //MARK: Public Methods
    
    public func start() {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            for provider in providers {
                
                assets.enumerateObjects({ (asset, _, _) in
                    if(provider.remoteFileList[asset] == nil && !provider.assetsToUpload.contains(asset)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.insert(asset)
                        
                    }
                })
                
                assetsToUploadCount = provider.assetsToUpload.count
                
                if let backblaze = provider as? B2 {
                    if (!backblaze.assetsToUpload.isEmpty && !Client.shared.isActive()) {
                        backblaze.startUploadTask()
                        
                    }
                }
            }
        } else {
            // No photo permission
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: Int) {
        if let asset = uploadingAssets?[task] {
            if (response.statusCode == 200) {
                for provider in providers {
                    if let backblaze = provider as? B2 {
                        do {
                            let json = try JSONSerialization.jsonObject(with: data)
                            print("\(json)")
                        } catch {
                            print("\(error.localizedDescription)")
                        }
                        
                        
                        if (!backblaze.assetsToUpload.isEmpty) {
                            backblaze.assetsToUpload.remove(asset)
                            //add to remotefilelist
                            
                            DispatchQueue.main.async {
                                backblaze.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
                            }
                        }
                        backblaze.startUploadTask()
                        //print("wouldve looped")
                    }
                }
            } // else if response 401 etc
        }
    }
}


