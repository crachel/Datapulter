//
//  Managed.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/9/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Promises

final class Managed: B2 {
    
    enum ManagedApplicationKey: String {
        case accountId
        case applicationKey
        case applicationKeyId
        case bucketId
        case capabilities
        case expirationTimestamp
        case keyName
        case namePrefix
    }
    
    private func createKey() {
        // unique user id: keyName, applicationKeyId, applicationKey
        
    }
    
}
