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

protocol AutoUploading {
    var uploadingAssets: [URLSessionTask: PHAsset] { get set }
    var assetsToUpload: Set<PHAsset> { get set }
    var totalAssetsToUpload: Int { get set }
    var totalAssetsUploaded: Int { get set }
}

class AutoUpload {
    
    //MARK: Properties

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
        
        //for provider in ProviderManager.shared.providers {
        //if var provider = ProviderManager.shared.providers.first {
        for provider in ProviderManager.shared.providers.providers.array {
            
            if(APIClient.shared.isActive()) {
                os_log("APIClient is already active", log: .autoupload, type: .error)
                
                return
            }
            
            provider.assetsToUpload.removeAll()
            
            assets.enumerateObjects({ (asset, _, _) in
                if(provider.remoteFileList[asset.localIdentifier] == nil) {
                    // object has not been uploaded
                    provider.assetsToUpload.insert(asset)
                }
            })
            
            provider.totalAssetsToUpload = provider.assetsToUpload.count
            
            if (provider.totalAssetsToUpload > 0) {
                
                provider.updateRing()
                
                os_log("found %d assets", log: .autoupload, type: .info, provider.totalAssetsToUpload)
                
                provider.hud("\(provider.totalAssetsToUpload) objects found.")
                
                initiate(initialRequests, provider)
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
                
                guard let error = task.error as? URLError else {
                    return
                }
                
                if (error.code != .cancelled) {
                    provider.assetsToUpload.insert(asset)
                    
                    //start another task, if asset exists
                    initiate(1, provider)
                }
            }
        }
    }
    
    public func handler(_ data: Data?,_ response: HTTPURLResponse,_ task: URLSessionTask) {
        if let provider = tasks.removeValue(forKey: task) {
            if let asset = provider.uploadingAssets.removeValue(forKey: task) {
                
                // perform any provider specific response handling
                provider.decodeURLResponse(response, data, task, asset)
                
            } else {
                os_log("no asset associated with task", log: .autoupload, type: .error)
            }
        } else {
            /*
             APIClient.didReceiveData should fire before APIClient.didCompleteWithError.
             Therefore any task that receives data upon completion, will have this handler
             called twice. It will 'fail' here on didCompleteWithError, not calling
             decodeURLResponse a second time since the task is no longer associated with
             a provider. This is expected behavior, effectively ignoring the unused
             task delegate.
             */
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
                    case providerError.largeFile:
                        // ignore large files (as defined by each provider) and allow the
                        // individual provider to manage chunking, uploading, etc
                        self.initiate(N, provider)
                    default:
                        os_log("%@", log: .autoupload, type: .error, error.localizedDescription)
                        break
                    }
                }
            }
        }
    }
}
