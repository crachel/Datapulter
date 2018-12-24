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

typealias JSON = [String: Any]

class AutoUpload {
    static let shared = AutoUpload()
    var session: Alamofire.Session
    
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
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            for provider in providers {
                if let backblaze = provider as? B2 {
                    // login, queue serial uploads
                    print(backblaze.name)
                    DispatchQueue.main.async {
                        if(backblaze.name == "My Backblaze B2 Remote") {
                        backblaze.cell?.ringView.startProgress(to: 25, duration: 6)
                        }
                        
                    }
                } // else if let s3, etc
            }
        } else {
            // no photo permission
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
