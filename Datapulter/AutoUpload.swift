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
import Alamofire
import PromiseKit
import UICircularProgressRing

class AutoUpload {
    
    //MARK: Properties
    
    class var shared: AutoUpload {
        struct Static {
            static let shared: AutoUpload = AutoUpload()
        }
        return Static.shared
    }

    var session: Alamofire.Session

    //MARK: Initialization
    
    init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.background")
        configuration.allowsCellularAccess = false
        session = Alamofire.Session(configuration: configuration)
    }
 
    //MARK: Public Methods
    
    public func request(urlrequest: URLRequest) -> Promise<[String: Any]> {
        return Promise { seal in
            session.request(urlrequest).responseJSON { (response) in
                switch response.result {
                case .success(let json):
                    // If there is not JSON data, cause an error (`reject` function)
                    guard let json = json as? [String: Any] else {
                        return seal.reject(AFError.responseValidationFailed(reason: .dataFileNil))
                    }
                    // Pass the JSON data into the fulfill function, so we can receive the value
                    seal.fulfill(json)
                case .failure(let error):
                    // Pass the error into the reject function, so we can check what causes the error
                    seal.reject(error)
                }
            }
        }
    }
    
    public func start(providers: [Provider]) {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            let assets = getCameraRollAssets()
        
            for provider in providers {
               
                assets.enumerateObjects({ (object, _, _) in
                    if(provider.remoteFileList[object] == nil && !provider.assetsToUpload.contains(object)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.append(object)
                        if (object.mediaType == .image) {
                            //object.requestContentEditingInput(with: PHContentEditingInputRequestOptions()) { (input, _) in
                              //  let fileURL = input!.fullSizeImageURL?.standardizedFileURL
                                //let data = NSData(contentsOfFile: fileURL!.path)!
                            //}
                        } else if (object.mediaType == .video) {
                            
                        }
                    }
                })
                
                
                
                //processuploadqueue
   
                DispatchQueue.main.async {
                    provider.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
                }
               
            }
            test(providers: providers)
        } else {
            // No photo permission
        }
    }

    //MARK: Private Methods
    
    private func test(providers: [Provider]) {
        for provider in providers {
            if(provider.name == "My Backblaze B2 Remote") {
                //provider.cell?.ringView.startProgress(to: 44, duration: 0)
                if let backblaze = provider as? B2 {
                    //backblaze.login()
                    //backblaze.test()
                }
            }
        }
        
        /*
            if(assets.count > 0) {
                print(assets[1].localIdentifier)
                print(assets[1].value(forKey: "filename") as! String)
                //return assets[0].value(forKey: "filename") as! String
            } else {
                return
            }
         */
   
    }
    
    private func processUploadQueue() {
        /*
         for each asset in assetsToUpload: [PHAsset]
            Router.upload_file(asset)
        */
        
    
    }
    
    private func getCameraRollAssets() -> PHFetchResult<PHAsset> {
        // A smart album that groups all assets that originate in the user’s own library (as opposed to assets from iCloud Shared Albums)
        let collection = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
    
        let assets = PHAsset.fetchAssets(in: collection.firstObject!, options: nil)
        
        return assets
    }
    
    private func fullResolutionImageData(asset: PHAsset) -> Data? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.resizeMode = .none
        options.isNetworkAccessAllowed = false // No iCloud
        options.version = .current
        var image: UIImage? = nil
        _ = PHCachingImageManager().requestImageData(for: asset, options: options) { (imageData, dataUTI, orientation, info) in
            if let data = imageData {
                image = UIImage(data: data)
            }
        }
        guard let imageJPEG = image?.jpegData(compressionQuality: 1.0) else {
            print("Could not get JPEG representation of UIImage")
            return nil
        }
        return imageJPEG // Full quality jpeg image data
    }
    
}
