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
import Promises

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
    
    public func start() {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            //let assets = Utility.getCameraRollAssets()
            
            for provider in providers {
                
                assets.enumerateObjects({ (asset, _, _) in
                    if(provider.remoteFileList[asset] == nil && !provider.assetsToUpload.contains(asset)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.insert(asset)
                    }
                })
                
                DispatchQueue.main.async {
                    provider.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
                }
                
                if let backblaze = provider as? B2 {
                    //UserDefaults.standard.removeObject(forKey: "authorizationToken")
                    if (!backblaze.assetsToUpload.isEmpty) {
                        for asset in backblaze.assetsToUpload {
                            /*
                             Utility.getDataFromAsset(asset) { data in
                             self.createUploadTask(data)
                             //provider.createUploadTask(data) -> URLRequest
                             }*/
                           // backblaze.assetsToUpload.remove(asset)
                            Utility.getUrlFromAsset(asset) { url in
                                print(url!)
                            }
                        }
                        
                        backblaze.getUploadUrl().then { result in
                            print(result.uploadUrl)
                        }
                    }
                }                
               
            }
            
        } else {
            // No photo permission
        }
    }
    
    private func createUploadTask(_ data: Data) {
        
        //let assetResources = PHAssetResource.assetResources(for: asset) // [PHAssetResource]
        //print(asset.creationDate?.millisecondsSince1970)
        //print(assetResources.first!.originalFilename)
        //print(data.hashWithRSA2048Asn1Header(.sha1))
    }

}


