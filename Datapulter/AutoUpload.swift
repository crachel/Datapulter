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
                    if (!backblaze.assetsToUpload.isEmpty) {
    
                        backblaze.startUploadTask()
                        
                    }
                }
               
            }
            
        } else {
            // No photo permission
        }
    }
    
    public func handler(_ json: Any,_ response: HTTPURLResponse,_ task: Int) {
        var asset: PHAsset
        // called by URLSession didReceive data delegate
        if (response.statusCode == 200) {
            //remove from assetstoupload
            //add to remotefilelist
            //asset = PHAsset.fetchAssets(withLocalIdentifiers: [uploadingAssets![task]!], options: nil)
           
                asset = uploadingAssets![task]!
            
            
            for provider in providers {
                if let backblaze = provider as? B2 {
                    if (!backblaze.assetsToUpload.isEmpty) {
                        backblaze.assetsToUpload.remove(asset)
                        
                        DispatchQueue.main.async {
                            backblaze.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
                        }
                    }
                    backblaze.startUploadTask()
                    //print("wouldve looped")
                }
            }
        }
    }
}


