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

class AutoUpload {
    
    //MARK: Properties

    var assets = PHFetchResult<PHAsset>()
    var providers = [Provider]()
    var tasks = [URLSessionTask: Provider]()
    
    var initialRequests: Int = 6
    
    //MARK: Singleton
    
    static let shared = AutoUpload()

    //MARK: Initialization
    
    private init() {
        PHPhotoLibrary.requestAuthorization { (status) in
            print("Status: \(status)")
        }
        
        print("batteryState \(UIDevice.current.batteryState.rawValue)")
    }
    
    //MARK: Public Methods
    
    public func start() {
        //if(PHPhotoLibrary.authorizationStatus() == .authorized && UIDevice.current.batteryState == .charging) {
        if(PHPhotoLibrary.authorizationStatus() == .authorized && !APIClient.shared.isActive()) {
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
                
                provider.hud("\(provider.totalAssetsToUpload) objects found.")
                
                if (provider.totalAssetsToUpload > 0) {
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
    
    public func clientError(_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                print("AutoUpload.clientError -> initiating new request")
                provider.assetsToUpload.insert(asset)
                
                //start another task, if asset exists
                initiate(1, provider)
            }
        }
    }
    
    public func handler(_ data: Data,_ response: HTTPURLResponse,_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                
                // perform any provider specific response handling
                provider.decodeURLResponse(response, data, task, asset)
                
                if (response.statusCode == 200) {
                    saveProviders()
                }
            } else {
                // no asset associated with task.
            }
        } else {
            // no provider associated with task.
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
                    print("AutoUpload.initiate -> ERROR: \(error.localizedDescription)")
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
    
    public func saveProviders() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: providers, requiringSecureCoding: false)
            try data.write(to: Provider.ArchiveURL)
        } catch {
            os_log("Failed to save providers...", log: OSLog.default, type: .error)
        }
    }
    
    public func loadProviders() -> [Provider]? {
        let fullPath = getDocumentsDirectory().appendingPathComponent("providers")
        if let nsData = NSData(contentsOf: fullPath) {
            do {
                let data = Data(referencing:nsData)
                
                if let loadedProviders = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Array<Provider> {
                    return loadedProviders
                }
            } catch {
                print("Couldn't read file.")
                return nil
            }
        }
        return nil
    }
    
    //MARK: Private Methods
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

}


