//
//  Utility.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/1/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos

class Utility {
    
    public static func getCameraRollAssets() -> PHFetchResult<PHAsset> {
        
        return PHAsset.fetchAssets(in: getCameraRollCollections().firstObject!, options: nil)
        
    }
    
    public static func getCameraRollCollections() -> PHFetchResult<PHAssetCollection> {
        
        // A smart album that groups all assets that originate in the user’s own library (as opposed to assets from iCloud Shared Albums)
        return PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
        
    }
    
    public static func getImageDataFromAsset(_ asset: PHAsset, completion:@escaping (_ data: Data) -> Void) {
        
        let imageRequestOptions = PHImageRequestOptions()
        var image = UIImage()
        
        imageRequestOptions.version = .current
        imageRequestOptions.isSynchronous = true
        
        
        PHImageManager.default().requestImageData(for: asset, options: imageRequestOptions) { (data, _, _, _) in
            if let data = data {
                image = UIImage(data: data)!
                guard let imageData = image.jpegData(compressionQuality: 1) else { return }
                
               
                completion(imageData)
            }
        }
    
    }
    
}
