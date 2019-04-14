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
        assets = Utility.getCameraRollAssets()
        
        if(PHPhotoLibrary.authorizationStatus() == .authorized) {
            for provider in providers {
                print("remoteFileList count: \(provider.remoteFileList.count)")
                print("Autoupload: Checking for assets.")
                DispatchQueue.main.async {
                    provider.cell?.hudLabel.text = "Checking for new media..."
                }
                assets.enumerateObjects({ (asset, _, _) in
                    
                    if(provider.remoteFileList[asset.localIdentifier] == nil && !provider.assetsToUpload.contains(asset)) {
                        // object has not been uploaded & is not already in upload queue
                        provider.assetsToUpload.insert(asset)
                    }
                })
                
                provider.totalAssetsToUpload = Float(provider.assetsToUpload.count)
                
                DispatchQueue.main.async {
                    provider.cell?.ringView.value = 0
                    provider.cell?.ringView.maxValue = CGFloat(provider.totalAssetsToUpload)
                    provider.cell?.hudLabel.text = "\(provider.totalAssetsToUpload) objects found."
                }
                
                if (provider.totalAssetsToUpload > 0 && !Client.shared.isActive()) {
                    /*while(Client.shared.activeTasks.count < 2 && provider.assetsToUpload.count > 0) {
                        if let asset = provider.assetsToUpload.popFirst() {
                            provider.getUrlRequest(asset).then { request, url in
                                let task = Client.shared.upload(request!, url!)
                                provider.uploadingAssets[task] = asset
                                self.tasks[task] = provider
                            }.catch { error in
                                    print("Cannot get URLRequest: \(error)")
                            }
                        }
                    }*/
                    func foo(_ N: Int) {
                        if(N > 0) {
                            if let asset = provider.assetsToUpload.popFirst() {
                                provider.getUrlRequest(asset).then { request, url in
                                    let task = Client.shared.upload(request!, url!)
                                    provider.uploadingAssets[task] = asset
                                    self.tasks[task] = provider
                                    foo(N - 1)
                                }.catch { error in
                                    print("Cannot get URLRequest: \(error)")
                                }
                            }
                        }
                    }
                    foo(10)
                    /*
                    provider.authorizeAccount().then { _, response in
                        if let response = response as? HTTPURLResponse,
                            response.statusCode == 200 {
                            foo(10)
                        }
                    }*/
                    
                    /*for asset in provider.assetsToUpload {
                        
                        if(Client.shared.activeTasks.count < 50) {
                            provider.getUrlRequest(asset).then { request, url in
                                let task = Client.shared.upload(request!, url!)
                                provider.uploadingAssets[task] = asset
                                self.tasks[task] = provider
                            }.catch { error in
                                print("Cannot get URLRequest: \(error)")
                            }
                        } else {
                            // exit loop and let delegates handle from here
                            break
                        }
                       //break
                    }*/
                    
                } else {
                    print("Autoupload: No assets found.")
                }
            }
        } else {
            // No photo permission
            print("Autoupload: No photo permission.")
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                if (response.statusCode == 200) {
                    do {
                        let json = try JSONSerialization.jsonObject(with: data) as! [String:Any]
                        provider.remoteFileList[asset.localIdentifier] = json
                    
                    } catch {
                        print("\(error.localizedDescription)")
                    }
                    
                    let fullPath = getDocumentsDirectory().appendingPathComponent("providers")
                    
                    do {
                        let data = try NSKeyedArchiver.archivedData(withRootObject: AutoUpload.shared.providers, requiringSecureCoding: false)
                        try data.write(to: fullPath)
                        os_log("Providers successfully saved.", log: OSLog.default, type: .debug)
                    } catch {
                        os_log("Failed to save providers...", log: OSLog.default, type: .error)
                    }
                    
                    if let _ = provider.assetsToUpload.remove(asset) {
                        // do nothing
                    } else {
                        print ("assetsToUpload did not contain asset")
                    }
                    print ("remote file list count \(provider.remoteFileList.count)")
                    
                    provider.totalAssetsUploaded += 1
                    
                    DispatchQueue.main.async {
                        provider.cell?.ringView.value = ((provider.cell?.ringView.value)! + 1)
                        
                        if ( Float((provider.cell?.ringView.currentValue)!) == provider.totalAssetsToUpload ){
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
                    if(Client.shared.activeTasks.count < 50 && provider.assetsToUpload.count > 0) {
                        print("delegate started new task")
                        if let asset = provider.assetsToUpload.popFirst() {
                            provider.getUrlRequest(asset).then { request, url in
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
                    provider.getUrlRequest(asset).then { request, url in
                        let task = Client.shared.upload(request!, url!)
                        provider.uploadingAssets[task] = asset
                        self.tasks[task] = provider
                    }.catch { error in
                        print("Cannot get URLRequest: \(error)")
                    }
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
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
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


