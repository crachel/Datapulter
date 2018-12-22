//
//  AutoUpload.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/13/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Photos
import Alamofire
import PromiseKit

class AutoUpload {
    
    //MARK: Properties
    
    //var providers: Provider?
    typealias JSON = [String: Any]
    var manager: Alamofire.Session
    
    init() {
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.background")
        manager = Alamofire.Session(configuration: configuration)
    }
    
    public func request(urlrequest: URLRequest) -> Promise<JSON> {
        return Promise { seal in
            manager.request(urlrequest).responseJSON { (response) in
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
