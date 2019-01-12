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
        
        imageRequestOptions.version = .current
        imageRequestOptions.isSynchronous = true
        
        PHImageManager.default().requestImageData(for: asset, options: imageRequestOptions) { (data, dataUTI, orientation, info) in
            if let data = data {

                completion(data)
                
                // do I want to convert HEIC to JPEG?
                //completion(UIImage(data: data)!.jpegData(compressionQuality: 1)!)
            }
        }
    
    }
    
    public static func getVideoDataFromAsset(_ asset: PHAsset, completion:@escaping (_ data: Data) -> Void) {
        
        let videoRequestOptions = PHVideoRequestOptions()
        
        videoRequestOptions.version = .current
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: videoRequestOptions) { (data, _, _) in
            if let data = data {
                // https://developer.apple.com/documentation/mobilecoreservices/uttype
                let asset = data as? AVURLAsset
                do {
                    let videoData = try Data(contentsOf: (asset?.url)!)
                    
                    completion(videoData)
                } catch  {
                    print("exception catch at block - while uploading video")
                }
                
            }
        }
        
    }
    
}

extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
}
