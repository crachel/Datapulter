//
//  Utility.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/1/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos
import Promises

class Utility {
    
    public static func getCameraRollAssets() -> PHFetchResult<PHAsset> {
        if let result = getCameraRollCollections().firstObject {
            return PHAsset.fetchAssets(in: result, options: nil)
        }
        
        return PHFetchResult()
    }
    
    public static func getCameraRollCollections() -> PHFetchResult<PHAssetCollection> {
        // A smart album that groups all assets (image, video, Live Photo) that originate in the user’s own library (as opposed to assets from iCloud Shared Albums)
        return PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
    }
    
    public static func getData(from asset: PHAsset, completion:@escaping (_ data: Data,_ url: URL) -> Void) {
        
        if (asset.mediaType == .image) {
            
            let imageRequestOptions = PHImageRequestOptions()
            
            imageRequestOptions.version = .current
            imageRequestOptions.isSynchronous = false
            imageRequestOptions.isNetworkAccessAllowed = false
            
            /*
            imageRequestOptions.progressHandler = {  (progress, error, stop, info) in
                print("progress: \(progress)")
            }*/
            PHImageManager.default().requestImageData(for: asset, options: imageRequestOptions) { (data, _, _, info) in
            //PHImageManager.default().requestImageData(for: asset, options: imageRequestOptions) { (data, dataUTI, orientation, info) in
                if let data = data,
                    let url = info?["PHImageFileURLKey"] as? URL {
                    completion(data, url)
                }
            }
            
        } else if (asset.mediaType == .video) {
            
            let videoRequestOptions = PHVideoRequestOptions()
            
            videoRequestOptions.version = .current
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoRequestOptions) { (data, _, _) in
                if let data = data,
                    let asset = data as? AVURLAsset {
                    
                    do {
                        let url = asset.url
                        let videoData = try Data(contentsOf: url)
                        
                        completion(videoData, url)
                    } catch  {
                        print("exception catch at block - while uploading video")
                    }
                    
                }
            }
            
        } // TODO: else if (asset.mediaType == .livephoto) {}
        
    }
    
    public static func getURL(ofPhotoWith mPhasset: PHAsset, completionHandler : @escaping ((_ responseURL : URL?) -> Void)) {
        
        if mPhasset.mediaType == .image {
            let options: PHContentEditingInputRequestOptions = PHContentEditingInputRequestOptions()
            options.canHandleAdjustmentData = {(adjustmeta: PHAdjustmentData) -> Bool in
                return true
            }
            mPhasset.requestContentEditingInput(with: options, completionHandler: { (contentEditingInput, info) in
                completionHandler(contentEditingInput!.fullSizeImageURL)
            })
        } else if mPhasset.mediaType == .video {
            let options: PHVideoRequestOptions = PHVideoRequestOptions()
            options.version = .original
            PHImageManager.default().requestAVAsset(forVideo: mPhasset, options: options, resultHandler: { (asset, audioMix, info) in
                if let urlAsset = asset as? AVURLAsset {
                    let localVideoUrl = urlAsset.url
                    completionHandler(localVideoUrl)
                } else {
                    completionHandler(nil)
                }
            })
        }
        
    }
   
    public static func objectIsType<T>(object: Any?, someObjectOfType: T.Type) -> Promise<T> {
        return Promise { fulfill, reject in
            if let object = object as? T {
                fulfill(object)
            } else {
                reject(Provider.providerError.optionalBinding)
            }
        }
    }

    
    public static func getSizeFromAsset(_ asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        
        if let resource = resources.first {
            if resource.responds(to: #selector(NSDictionary.fileSize)) {
                let unsignedInt64 = resource.value(forKey: "fileSize") as! CLong
                return Int64(bitPattern: UInt64(unsignedInt64))
            }
        }
        
        return 0
    }
    
}
