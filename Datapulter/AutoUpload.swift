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
    
    var assets = PHFetchResult<PHAsset>()
    var providers = [Provider]()
    var tasks = [URLSessionTask: Provider]()
    
    var initialRequests: Int = 6

    //MARK: Initialization
    
    private init() {
        PHPhotoLibrary.requestAuthorization { (status) in
            print("Status: \(status)")
        }
    }
    
    //MARK: Public Methods
    
    public func start() {
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            assets = Utility.getCameraRollAssets()
            
            for provider in providers {
                print("AutoUpload.start -> remoteFileList count: \(provider.remoteFileList.count)")
                print("Autoupload.start -> checking for assets...", terminator:"")
                
                assets.enumerateObjects({ (asset, _, _) in
                    if(provider.remoteFileList[asset.localIdentifier] == nil && !provider.assetsToUpload.contains(asset)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.insert(asset)
                        provider.totalAssetsToUpload += 1
                    }
                })
                
                DispatchQueue.main.async {
                    provider.cell?.ringView.value = 0
                    provider.cell?.ringView.maxValue = CGFloat(provider.totalAssetsToUpload)
                    provider.cell?.hudLabel.text = "\(provider.totalAssetsToUpload) objects found."
                }
                
                if (provider.totalAssetsToUpload > 0) {
                //if (provider.totalAssetsToUpload > 0 && !Client.shared.isActive()) {
                    print("found \(provider.totalAssetsToUpload)")
                    
                    print("AutoUpload.initiate -> initiating \(initialRequests) requests")
                    initiate(initialRequests, provider)
                  
                } else {
                    print("found none")
                }
            }
        } else {
            // No photo permission
            print("AutoUpload.start -> no photo permission")
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                
                // perform any provider specific response handling
                provider.decodeURLResponse(response, data, task)
                
                if (response.statusCode == 200) {
                    
                    // update
                    provider.totalAssetsUploaded += 1
                    provider.remoteFileList[asset.localIdentifier] = data
                    
                    // save
                    let fullPath = getDocumentsDirectory().appendingPathComponent("providers")
                    
                    do {
                        let data = try NSKeyedArchiver.archivedData(withRootObject: AutoUpload.shared.providers, requiringSecureCoding: false)
                        try data.write(to: fullPath)
                    } catch {
                        os_log("Failed to save providers...", log: OSLog.default, type: .error)
                    }
                    
                    // refresh ui
                    DispatchQueue.main.async {
                        provider.cell?.ringView.value = ((provider.cell?.ringView.value)! + 1)
                        
                        
                        if ( Int((provider.cell?.ringView.currentValue)!) == (provider.totalAssetsToUpload) ){
                            DispatchQueue.main.async {
                                provider.cell?.hudLabel.text = "Done uploading!"
                            }
                        }
                        
                        if(provider.totalAssetsToUpload == provider.totalAssetsUploaded) {
                            provider.cell?.ringView.innerRingColor = .green
                            provider.cell?.ringView.maxValue = 100
                            //provider.cell?.ringView.valueIndicator = "%"
                            provider.cell?.ringView.valueFormatter = UICircularProgressRingFormatter(valueIndicator: "%", rightToLeft: false, showFloatingPoint: false, decimalPlaces: 0)
                            
                            provider.cell?.ringView.value = 100
                        }
                    }
                    
                    //start another task, if asset exists
                    initiate(1, provider)
                    
                } else if (400...401).contains(response.statusCode)  {
                    print("AutoUpload.handler -> response statuscode 400 or 401")
                } else if (response.statusCode == 503) {
                    print("AutoUpload.handler -> retry 503 task")
                    
                    // re insert failed asset and initiate another request
                    provider.assetsToUpload.insert(asset)
                    initiate(1, provider)
                } // else if response 500 etc
                
            } else {
                // no asset associated with task.
            }
        } else {
            // no provider associated with task. likely user quit app while task was running.
            // need to save to disk some how. core data or realm or something
        }
    }
    
    public func initiate(_ N: Int,_ provider: Provider) {
        if (N > 0) {
            if let asset = provider.assetsToUpload.popFirst() {
                provider.getUploadFileURLRequest(from: asset).then { request, data in
                    if let request = request,
                        let data = data {
                        
                        let task = APIClient.shared.upload(request, data)
                        provider.uploadingAssets[task] = asset
                        self.tasks[task] = provider
                        
                        self.initiate(N - 1, provider)
                    }
                }.catch { error in
                    print("AutoUpload.initiate -> getUploadFileURLRequest: \(error)")
                    switch error {
                    case Provider.providerError.largeFile:
                        print("AutoUpload.initiate -> initiating new request")
                        self.initiate(N, provider)
                    default:
                        break
                    }
                }
            } else {
                print("AutoUpload.initiate -> assetsToUpload is empty. stopping")
            }
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

}


