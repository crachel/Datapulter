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

typealias JSON = [String: Any]

class AutoUpload {
    
    class var shared: AutoUpload {
        struct Static {
            static let shared: AutoUpload = AutoUpload()
        }
        return Static.shared
    }
    
    //static let shared = AutoUpload()
    var session: Alamofire.Session
    var providers: [Provider]?

    
    init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.background")
        configuration.allowsCellularAccess = false
        session = Alamofire.Session(configuration: configuration)
    }
 
    public func request(urlrequest: URLRequest) -> Promise<JSON> {
        return Promise { seal in
            session.request(urlrequest).responseJSON { (response) in
                switch response.result {
                case .success(let json):
                    // If there is not JSON data, cause an error (`reject` function)
                    guard let json = json as? JSON else {
                        return seal.reject(AFError.responseValidationFailed(reason: .dataFileNil))
                    }
                    // pass the JSON data into the fulfill function, so we can receive the value
                    seal.fulfill(json)
                case .failure(let error):
                    // pass the error into the reject function, so we can check what causes the error
                    seal.reject(error)
                }
            }
        }
    }
    
    func start(providers: [Provider]) {
        self.providers = providers
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            let assets = getCameraRollAssets()
        
            for provider in providers {
               
                assets.enumerateObjects({ (object, _, _) in
                    if(provider.remoteFileList[object] == nil && !provider.assetsToUpload.contains(object)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.append(object)
                    }
                })
                
                //processuploadqueue
   
                DispatchQueue.main.async {
                    //if(provider.name == "My Backblaze B2 Remote") {
                    //provider.cell?.ringView.startProgress(to: 44, duration: 0)
                    provider.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
                    //}
                }
               
            }
            test(providers: providers)
        } else {
            // no photo permission
        }
    }

    func test(providers: [Provider]) {
        //let assets = getCameraRollAssets()
        
        for provider in providers {
            if(provider.name == "My Backblaze B2 Remote") {
                //provider.cell?.ringView.startProgress(to: 44, duration: 0)
                if let backblaze = provider as? B2 {
                    //backblaze.login()
                    backblaze.test()
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
    
    func processUploadQueue() {
        /*
         provider.login
         provider.upload
        */
        
    
    }
    
    func getCameraRollAssets() -> PHFetchResult<PHAsset> {
        // A smart album that groups all assets that originate in the user’s own library (as opposed to assets from iCloud Shared Albums)
        let collection = PHAssetCollection.fetchAssetCollections(with: PHAssetCollectionType.smartAlbum, subtype: PHAssetCollectionSubtype.smartAlbumUserLibrary, options: nil)
    
        let assets = PHAsset.fetchAssets(in: collection.firstObject!, options: nil)
        
        return assets
    }
    
}
