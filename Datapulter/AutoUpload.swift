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
    
    var assets: PHFetchResult<PHAsset>!
    
    var providers = [Provider]()

    //MARK: Initialization
    
    private init() {
        
        assets = Utility.getCameraRollAssets()
        
    }
 
    //MARK: Public Methods
    
    public func start(provider: B2) {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            let assets = Utility.getCameraRollAssets()
            
            assets.enumerateObjects({ (asset, _, _) in
                if(provider.remoteFileList[asset] == nil && !provider.assetsToUpload.contains(asset)) {
                    // object has not been uploaded & is not already in upload queue
                    
                    provider.assetsToUpload.append(asset)
                    
                    let assetResources = PHAssetResource.assetResources(for: asset) // [PHAssetResource]
                    
                    print(asset.creationDate?.millisecondsSince1970)
                    print(assetResources.first!.originalFilename)
                    
                    
                    
                    if (asset.mediaType == .image) {
                        Utility.getImageDataFromAsset(asset) { data in
                            //print(SHA1.hexString(from: &data))
                            self.createUploadTask()
                        }
                        /*
                        object.requestContentEditingInput(with: PHContentEditingInputRequestOptions()) { (input, _) in
                            let fileURL = input!.fullSizeImageURL?.standardizedFileURL
                            let data = NSData(contentsOfFile: fileURL!.path)!
                        }*/
                    } else if (asset.mediaType == .video) {
                        Utility.getVideoDataFromAsset(asset) { data in
                            
                            self.createUploadTask()
                        }
                    }
                }
            })
            
            //provider.test2()
            //print(provider.uploadurl?.uploadUrl)
            

            DispatchQueue.main.async {
                provider.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
            }
            
        } else {
            // No photo permission
        }
    }
    
    private func createUploadTask() {
        
    }

}
