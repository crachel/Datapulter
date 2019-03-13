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
//import UICircularProgressRing
import Promises

class AutoUpload {
    
    //MARK: Properties
    
    static let shared = AutoUpload()
    
    var assets: PHFetchResult<PHAsset>
    var providers = [Provider]()
    var tasks = [URLSessionTask: Provider]()
    
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
                
                if (totalAssetsToUpload > 0 && !Client.shared.isActive()) {
                    for asset in provider.assetsToUpload {
                        
                        provider.getUrlRequest(asset).then { request, url in
                            let task = Client.shared.upload(request!, url!)
                            provider.uploadingAssets[task] = asset
                            self.tasks[task] = provider
                        }.catch { error in
                            print("Cannot get URLRequest: \(error)")
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
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                if (response.statusCode == 200) {
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
                    print ("remote file list count \(provider.remoteFileList.count)")
                } else if (400...401).contains(response.statusCode)  {
                    print ("handler: response statuscode 400 or 401")
                } // else if response 500 etc
                
                print("tasks count \(tasks.count)")
                print("uploadingassets count \(provider.uploadingAssets.count)")
            } else {
                // no asset associated with task.
            }
        } else {
            // no provider associated with task. likely user quit app while task was running.
            // need to save to disk some how. core data or realm or something
        }
    }
    
    /*
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
 */
}


