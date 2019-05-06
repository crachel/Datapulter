//
//  PHAsset.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/17/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import Photos

extension PHAsset {
    var originalFilename: String? {
        if let assetResources = PHAssetResource.assetResources(for: self).first {
            return assetResources.originalFilename
        }
        return nil
    }
    var percentEncodedFilename: String? {
        if let assetResources = PHAssetResource.assetResources(for: self).first {
            return assetResources.originalFilename.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)
        }
        return nil
    }
    
    var size: Int64 {
        let resources = PHAssetResource.assetResources(for: self)
        
        if let resource = resources.first {
            if resource.responds(to: #selector(NSDictionary.fileSize)) {
                let unsignedInt64 = resource.value(forKey: "fileSize") as! CLong
                return Int64(bitPattern: UInt64(unsignedInt64))
            }
        }
        return 0
    }
}
