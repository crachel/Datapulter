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
    
    var providers = [Provider]()

    var assets = PHFetchResult<PHAsset>()
    var tasks = [URLSessionTask: Provider]()
    
    var initialRequests: Int = 6 // start n threads
    
    //MARK: Singleton
    
    static let shared = AutoUpload()

    //MARK: Initialization
    
    private init() {
        PHPhotoLibrary.requestAuthorization { (status) in
            os_log("PHAuthorizationStatus = %d", log: .autoupload, type: .info, status.rawValue)
        }
    }
    
    //MARK: Public Methods
    
    public func start() {
        if (PHPhotoLibrary.authorizationStatus() != .authorized) {
            os_log("no photo permission", log: .autoupload, type: .error)
            return
        }
        os_log("started", log: .autoupload, type: .info)
        
        assets = Utility.getCameraRollAssets()
        
        for provider in providers {
            
            //provider.check()
            
            let s3 = S3(name: "<#T##String#>", accessKeyID: "<#T##String#>", secretAccessKey: "<#T##String#>", remoteFileList: [:])
            s3.authorizeAccount()
            
           // print("test".hmac_sha256(key: "test"))
            
            if(APIClient.shared.isActive()) {
                os_log("APIClient is active", log: .autoupload, type: .error)
                
                provider.hud("Nothing to upload!")
                return
            }
            
            assets.enumerateObjects({ (asset, _, _) in
                if(provider.remoteFileList[asset.localIdentifier] == nil && !provider.assetsToUpload.contains(asset)) {
                    // object has not been uploaded & is not already in upload queue
                    provider.assetsToUpload.insert(asset)
                    provider.totalAssetsToUpload += 1
                }
            })
            
            if (provider.totalAssetsToUpload > 0) {
                
                provider.updateRing()
                
                os_log("found %d assets", log: .autoupload, type: .info, provider.totalAssetsToUpload)
                
                provider.hud("\(provider.totalAssetsToUpload) objects found.")
                
                //initiate(initialRequests, provider)
            } else {
                os_log("no assets to upload", log: .autoupload, type: .info)
                
                provider.hud("Nothing to upload!")
            }
        }
    }
    
    public func clientError(_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                os_log("clientError", log: .autoupload, type: .info)
                
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
                os_log("no asset associated with task", log: .autoupload, type: .error)
            }
        } else {
            os_log("no provider associated with task", log: .autoupload, type: .error)
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
                    switch error {
                    case Provider.providerError.largeFile:
                        self.initiate(N, provider)
                    default:
                        os_log("%@", log: .autoupload, type: .error, error.localizedDescription)
                        break
                    }
                }
            }
        }
    }
    
    public func saveProviders() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: providers, requiringSecureCoding: false)
            try data.write(to: Provider.ArchiveURL)
        } catch {
            os_log("failed to save providers", log: .autoupload, type: .error)
        }
    }
    
    public func loadProviders() -> [Provider]? {
        let fullPath = Provider.ArchiveURL
        if let nsData = NSData(contentsOf: fullPath) {
            do {
                let data = Data(referencing:nsData)
                
                if let loadedProviders = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Array<Provider> {
                    return loadedProviders
                }
            } catch {
                os_log("failed to load providers", log: .autoupload, type: .error)
                return nil
            }
        }
        return nil
    }
}
