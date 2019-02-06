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

class AutoUpload {
    
    //MARK: Properties
    static let shared = AutoUpload()
    
    typealias TaskId = Int
    
    var assets: PHFetchResult<PHAsset>
    
    var providers = [Provider]()
    var uploadingAssets: [TaskId: PHAsset]? // URLSessionTask associated with each PHAsset
    
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
                hud("\(totalAssetsToUpload) assets to upload.")
                
                if let backblaze = provider as? B2 {
                    if (totalAssetsToUpload > 0 && !Client.shared.isActive()) {
                        for asset in backblaze.assetsToUpload {
                            backblaze.getUrlRequest(asset).then { request, url in
                                let taskId = Client.shared.upload(request!, url!)
                                AutoUpload.shared.uploadingAssets = [taskId: asset]
                            }.catch { error in
                                print("Cannot get URLRequest: \(error)")
                            }
                        }
                    }
                }
            }
        } else {
            // No photo permission
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: Int) {
        
        if let asset = uploadingAssets?[task] {
            if (response.statusCode == 200) {
                print ("got here")
                for provider in providers {
                    if let backblaze = provider as? B2 {
                       
                        do {
                            let json = try JSONSerialization.jsonObject(with: data) as! [String:Any]
                            backblaze.remoteFileList[asset] = json
                        } catch {
                            print("\(error.localizedDescription)")
                        }
                        
                        if (!backblaze.assetsToUpload.isEmpty) {
                            backblaze.assetsToUpload.remove(asset)
                        }
                        //let totalUploads = totalAssetsToUpload - backblaze.assetsToUpload.count
                        //hud("uploaded \(totalUploads)")
                        print ("remote file list count \(backblaze.remoteFileList.count)")
                        // ADD THIS BACK!!!!!
                        //backblaze.startUploadTask()
                        //print("wouldve looped")
                    }
                }
            } // else if response 401 etc
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


