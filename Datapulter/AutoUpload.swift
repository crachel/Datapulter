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
    
    var assets: PHFetchResult<PHAsset>
    var providers = [Provider]()
    
    var uploadingAssets = [URLSessionTask: PHAsset]()
       
    var totalAssetsToUpload: Int = 0

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
                
                totalAssetsToUpload = provider.assetsToUpload.count
                
               
                //all(provider.assetsToUpload.map { provider.getUrlRequest($0) } ).then
                
                /*
                 
                 create pool of url/uploadtokens. maybe 50?
                 
                 */
                
                /*
                if(provider.uploadUrlPool.count < provider.uploadUrlPool.capacity) {
                } else {
                    print("uploadurlpool full. start pulling from here")
                }*/
                
                
                if (totalAssetsToUpload > 0 && !Client.shared.isActive()) {
                    
                    for asset in provider.assetsToUpload {
                        
                        /*
                        provider.getUrlRequest(asset).then { request, url in
                        
                            //provider.uploadUrlPool.append([request?.value(forHTTPHeaderField: "Authorization"):request?.url])
                            
                            let taskId = Client.shared.upload(request!, url!)
                            self.uploadingAssets[taskId] = asset
                        }.catch { error in
                                print("Cannot get URLRequest: \(error)")
                        }*/
                        
                        // PHAsset
                        // Task
                        // GetUrlResponse
                        
                        
                        if let backblaze = provider as? B2 {
                            
                            backblaze.getUploadUrlApi().then { data, response in
                                try JSONDecoder().decode(GetUploadURLResponse.self, from: data!)
                            }.then { data in
                                backblaze.returnUpObj(asset, data)
                            }.then { object in
                                backblaze.prepareRequest(from: object!)
                            }.then { request, url in
                                let task = Client.shared.upload(request!, url!)
                                self.uploadingAssets[task] = asset
                                let uploadObject = UploadObject2(asset: asset, uploadUrl:(request?.url)!, uploadToken:(request?.value(forHTTPHeaderField: "Authorization"))!)
                                provider.uploadingAssets[task] = uploadObject
                            }
                            
                            /*
                            backblaze.getUploadUrlApi().then { data, response in
                                try JSONDecoder().decode(GetUploadURLResponse.self, from: data!)
                            }.then { data in
                                backblaze.urlPool.append(data)
                            }.then {
                                backblaze.getUrlRequest(asset)
                            }.then { request, url in
                                let task = Client.shared.upload(request!, url!)
                                self.uploadingAssets[task] = asset
                                let uploadObject = UploadObject2(asset: asset, uploadUrl:(request?.url)!, uploadToken:(request?.value(forHTTPHeaderField: "Authorization"))!)
                                provider.uploadingAssets[task] = uploadObject
                            }.catch { error in
                                print("unhandled error: \(error.localizedDescription)")
                            }*/
                        }
                        
                        break
                    }
                    
                }
            }
        } else {
            // No photo permission
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: URLSessionTask) {
        
        if let asset = uploadingAssets[task] {
            if (response.statusCode == 200) {
                for provider in providers {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as! [String:Any]
                        provider.remoteFileList[asset] = json
                    } catch {
                        print("\(error.localizedDescription)")
                    }
                    
                    if let _ = provider.assetsToUpload.remove(asset) {
                        // do nothing
                    } else {
                        print ("assetsToUpload did not contain asset")
                    }
                    print("upAsset \(String(describing: provider.uploadingAssets[task]?.uploadUrl))")
                    
                    //let totalUploads = totalAssetsToUpload - backblaze.assetsToUpload.count
                    //hud("uploaded \(totalUploads)")
                    //print ("uploadurlpool count \(provider.uploadUrlPool.count)")
                    /*
                     if(provider.uploadUrlPool.count < provider.uploadUrlPool.capacity) {
                        provider.uploadUrlPool.append([(task.originalRequest?.value(forHTTPHeaderField: "Authorization"))!:(task.originalRequest?.url)!])
                     } else {
                     print("uploadurlpool full. start pulling from here")
                     }
                     print("uploadurlpool count \(provider.uploadUrlPool.count)")
                     print("uploadurlpool capacity \(provider.uploadUrlPool.capacity)")*/
                    print ("remote file list count \(provider.remoteFileList.count)")
                }
            } else { // else if response 401 etc
                print ("non 200 statusCode received.")
            }
        }
    }
    
    public func hud (_ totalBytesSent: Float,_ totalBytesExpectedToSend: Float) {
        DispatchQueue.main.async {
            let value = (totalBytesSent / totalBytesExpectedToSend * 100)
            self.providers[0].cell?.ringView.value = UICircularProgressRing.ProgressValue(value)
        }
    }
    
    public func hud (_ text: String) {
        DispatchQueue.main.async {
            self.providers[0].cell?.hudLabel.text = text
        }
    }
}


