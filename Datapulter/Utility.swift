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
        
    public static func getDataFromAsset(_ asset: PHAsset, completion:@escaping (_ data: Data) -> Void) {
        
        if (asset.mediaType == .image) {
            
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
            
        } else if (asset.mediaType == .video) {
            
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
    
    public static func getUrlFromAsset(_ asset: PHAsset, completionHandler : @escaping ((_ responseURL : URL?) -> Void)) {
        if asset.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            asset.requestContentEditingInput(with: options, completionHandler: {(contentEditingInput: PHContentEditingInput?, info: [AnyHashable : Any]) -> Void in
                completionHandler(contentEditingInput!.fullSizeImageURL as URL?)
            })
        } else if asset.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .current
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options, resultHandler: {(asset: AVAsset?, audioMix: AVAudioMix?, info: [AnyHashable : Any]?) -> Void in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl: URL = urlAsset.url as URL
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
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


