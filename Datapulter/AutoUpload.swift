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
    static let shared = AutoUpload()

    var sessionB2: Alamofire.Session
    
    var assets: PHFetchResult<PHAsset>!
    
    //typealias completionHandler = (Data?, URLResponse?, Error?) -> Void
    
    //var tasks = [URL: [completionHandler]]()

    //MARK: Initialization
    
    private init() {
        let configurationB2 = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.B2.background")
        configurationB2.allowsCellularAccess = false
        sessionB2 = Alamofire.Session(configuration: configurationB2)
        assets = Utility.getCameraRollAssets()
    }
 
    //MARK: Public Methods
    
    public func start(provider: B2) {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            let assets = Utility.getCameraRollAssets()
        
            assets.enumerateObjects({ (object, _, _) in
                if(provider.remoteFileList[object] == nil && !provider.assetsToUpload.contains(object)) {
                    // object has not been uploaded & is not already in upload queue
                    provider.assetsToUpload.append(object)
                    //provider.assetsToUpload.foreach
                    if (object.mediaType == .image) {
                        /*
                        object.requestContentEditingInput(with: PHContentEditingInputRequestOptions()) { (input, _) in
                            let fileURL = input!.fullSizeImageURL?.standardizedFileURL
                            let data = NSData(contentsOfFile: fileURL!.path)!
                        }*/
                    } else if (object.mediaType == .video) {
                        
                    }
                }
            })
            
            //provider.login()
            
            

            DispatchQueue.main.async {
                provider.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
            }
            
        } else {
            // No photo permission
        }
    }
    
    public func request(urlrequest: URLRequest) -> Promise<[String: Any]> {
        return Promise { seal in
            sessionB2.request(urlrequest).responseJSON { (response) in
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
}
