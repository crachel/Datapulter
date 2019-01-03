//
//  Utility.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/1/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos

//class Utility: PHPhotoLibraryChangeObserver {
class Utility {
    public static func getCameraRollAssets() -> PHFetchResult<PHAsset> {
        
        let collection = getCameraRollCollections()
        
        let assets = PHAsset.fetchAssets(in: collection.firstObject!, options: nil)
        
        return assets
    }
    
    public static func getCameraRollCollections() -> PHFetchResult<PHAssetCollection> {
        // A smart album that groups all assets that originate in the user’s own library (as opposed to assets from iCloud Shared Albums)
        return PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
    }
    
}
