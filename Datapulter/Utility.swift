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
            
            //autoreleasepool(invoking: { () -> () in
                PHImageManager.default().requestImageData(for: asset, options: imageRequestOptions) { (data, dataUTI, orientation, info) in
                    if let data = data {
                        completion(data)
                    }
                }
            //})
            
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


/*
extension UIApplication {
    var isBackground: Bool {
        return UIApplication.shared.applicationState == .background
    }
}

extension OutputStream {
    @discardableResult
    func write(_ string: String) -> Int {
        guard let data = string.data(using: .utf8) else { return -1 }
        return data.withUnsafeBytes { (buffer: UnsafePointer<UInt8>) -> Int in
            write(buffer, maxLength: data.count)
        }
    }
    
    @discardableResult
    func append(contentsOf url: URL) -> Int {
        guard let inputStream = InputStream(url: url) else { return -1 }
        inputStream.open()
        let bufferSize = B2.const.defaultChunkSize
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        var bytes = 0
        var totalBytes = 0
        repeat {
            bytes = inputStream.read(&buffer, maxLength: bufferSize)
            if bytes > 0 {
                write(buffer, maxLength: bytes)
                totalBytes += bytes
            }
        } while bytes > 0
        
        inputStream.close()
        
        return bytes < 0 ? bytes : totalBytes
    }
}
*/
