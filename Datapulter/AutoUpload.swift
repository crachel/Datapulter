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
import UICircularProgressRing
import Promises

class AutoUpload {
    
    //MARK: Properties
    static let shared = AutoUpload()
    
    var assets: PHFetchResult<PHAsset>!
    
    var providers = [Provider]()

    //MARK: Initialization
    
    private init() {
        
        assets = Utility.getCameraRollAssets()
        
    }
 
    //MARK: Public Methods
    
    public func start() {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            
            for provider in providers {
                
                assets.enumerateObjects({ (asset, _, _) in
                    if(provider.remoteFileList[asset] == nil && !provider.assetsToUpload.contains(asset)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.insert(asset)
                    }
                })
                
                DispatchQueue.main.async {
                    provider.cell?.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
                }
                
                if let backblaze = provider as? B2 {
                    if (!backblaze.assetsToUpload.isEmpty) {
                        /*
                        for asset in backblaze.assetsToUpload {
                            print(Utility.getSizeFromAsset(asset))
                            Utility.getSizeFromAsset(asset) { fileSize in
                                print("filesize \(fileSize)")
                            }
                            Utility.getUrlFromAsset(asset) { url in
                                print(url!)
                            }
                        }*/
                        
                        
                        
                        backblaze.getUploadUrl().then { result in
                            var urlRequest: URLRequest
                            let assetResources = PHAssetResource.assetResources(for: backblaze.assetsToUpload.first!)
                            
                            urlRequest = URLRequest(url: result.uploadUrl)
                            urlRequest.httpMethod = "POST"
                            urlRequest.setValue(result.authorizationToken, forHTTPHeaderField: "Authorization")
                            urlRequest.setValue(String(Utility.getSizeFromAsset(backblaze.assetsToUpload.first!)), forHTTPHeaderField: "Content-Length")
                            urlRequest.setValue("b2/x-auto", forHTTPHeaderField: "Content-Type")
                            urlRequest.setValue(assetResources.first!.originalFilename, forHTTPHeaderField: "X-Bz-File-Name")
                            urlRequest.setValue(String(backblaze.assetsToUpload.first!.creationDate!.millisecondsSince1970), forHTTPHeaderField: "X-Bz-Info-src_last_modified_millis")
                            
                            Utility.getDataFromAsset(backblaze.assetsToUpload.first!) { data in
                                urlRequest.setValue(data.hashWithRSA2048Asn1Header(.sha1), forHTTPHeaderField: "X-Bz-Content-Sha1")
                                
                                Utility.getUrlFromAsset(backblaze.assetsToUpload.first!) { url in
                                    _ = Client.shared.upload(urlRequest, url!)
                                }
                                
                            }
                            
                            
                            print(result.uploadUrl)
                        }
                    }
                }
               
            }
            
        } else {
            // No photo permission
        }
    }
    
    private func createUploadTask(_ data: Data) {
        
        //let assetResources = PHAssetResource.assetResources(for: asset) // [PHAssetResource]
        //print(asset.creationDate?.millisecondsSince1970)
        //print(assetResources.first!.originalFilename)
        //print(data.hashWithRSA2048Asn1Header(.sha1))
        
    }

}


