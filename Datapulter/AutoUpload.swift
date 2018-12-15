//
//  AutoUpload.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/13/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Photos

class AutoUpload {
    var providers: Provider?
    
    func start() {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
        } else {
            
        }
    }

    func test() -> String {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            let assets = getCameraRollAssets()
            if(assets.count > 0) {
                print(assets[0])
                return assets[0].value(forKey: "filename") as! String
            } else {
                return "no camera roll assets"
            }
        } else {
            return "no photo permission"
        }
    }
    
    func uploadAssets() {
    
    }
    
    func getCameraRollAssets() -> PHFetchResult<PHAsset> {
        
        // A smart album that groups all assets that originate in the user’s own library (as opposed to assets from iCloud Shared Albums)
        let collection  = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
        
        //let fetchOptions = PHFetchOptions()
        
        return PHAsset.fetchAssets(in: collection[0], options: nil)
    }
    
}
