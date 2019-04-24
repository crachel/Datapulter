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
                print("Provider: remoteFileList count: \(provider.remoteFileList.count)")
                print("Autoupload: Checking for assets...", terminator:"")
                
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
                
                if (provider.totalAssetsToUpload > 0 && !Client.shared.isActive()) {
                    print("found \(provider.totalAssetsToUpload)")
                    func initiate(_ N: Int) {
                        if (N > 0) {
                            if let asset = provider.assetsToUpload.popFirst() {
                                provider.getURLRequest(from: asset).then { request, url in
                                    if let request = request,
                                        let url = url {
                                        let task = Client.shared.upload(request, url)
                                        provider.uploadingAssets[task] = asset
                                        self.tasks[task] = provider
                                        
                                        initiate(N - 1)
                                    }
                                }.catch { error in
                                    print("AutoUpload: getUrlRequest -> \(error)")
                                    switch error {
                                    case Provider.providerError.largeFile:
                                        /*
                                         skip largeFile, allowing the provider to handle the particulars of uploading it.
                                         this shouldnt be N-1. probably just N. then the provider keeps track of large
                                         assets?
                                         */
                                        initiate(N)
                                    default:
                                        break
                                    }
                                }
                            } else {
                                print("AutoUpload: assetsToUpload is empty. Stopping.")
                            }
                        }
                    }
                    /*
                     start N threads to "charge" the url pool. they will complete then delegate->handler pulls urls
                     out of the pool with no network call needed.
                     */
                    initiate(6)
                    
                  
                } else {
                    print("found none")
                }
            }
        } else {
            // No photo permission
            print("AutoUpload: No photo permission.")
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                
                provider.decodeURLResponse(response: response, data: data,task: task)
                
                if (response.statusCode == 200) {
                    provider.totalAssetsUploaded += 1
                
                    provider.remoteFileList[asset.localIdentifier] = data
                    
                    let fullPath = getDocumentsDirectory().appendingPathComponent("providers")
                    
                    do {
                        let data = try NSKeyedArchiver.archivedData(withRootObject: AutoUpload.shared.providers, requiringSecureCoding: false)
                        try data.write(to: fullPath)
                    } catch {
                        os_log("Failed to save providers...", log: OSLog.default, type: .error)
                    }
                    
                    
                    
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
                    /*
                     might not work in the background with the promises
                     */
                    //start another task, if asset exists
                    if(Client.shared.activeTasks.count < 50 && provider.assetsToUpload.count > 0) {
                        print("delegate started new task")
                        if let asset = provider.assetsToUpload.popFirst() {
                            provider.getURLRequest(from: asset).then { request, url in
                                let task = Client.shared.upload(request!, url!)
                                provider.uploadingAssets[task] = asset
                                self.tasks[task] = provider
                            }.catch { error in
                                print("Cannot get URLRequest: \(error)")
                            }
                        }
                    } else {
                        
                    }
                } else if (400...401).contains(response.statusCode)  {
                    print ("handler: response statuscode 400 or 401")
                } else if (response.statusCode == 503) {
                    //retry
                    print("delegate retry 503 task")
                    provider.getURLRequest(from: asset).then { request, url in
                        let task = Client.shared.upload(request!, url!)
                        provider.uploadingAssets[task] = asset
                        self.tasks[task] = provider
                    }.catch { error in
                        print("Cannot get URLRequest: \(error)")
                    }
                } // else if response 500 etc
                
            } else {
                // no asset associated with task.
            }
        } else {
            // no provider associated with task. likely user quit app while task was running.
            // need to save to disk some how. core data or realm or something
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

}


