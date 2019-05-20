//
//  Managed.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/9/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Promises

final class Managed: S3 {
    
    /*
     $key = bin2hex(random_bytes(32));  // Note, if you lose this key, you lose access to all objects encrypted by it
     
     //Create customer key
     $customerKey = hash('sha256',$key,true);
     
     // Create customer MD5 Key
     $customerMd5Key =md5($customerKey, true);
     
     //x-amz-server-side-encryption-customer-key:g0lCfA3Dv40jZz5SQJ1ZukLRFqtI5WorC/8SEEXAMPLE
     //x-amz-server-side-encryption-customer-key-MD5:ZjQrne1X/iTcskbY2example
     //x-amz-server-side-encryption-customer-algorithm:AES256
     */
    
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
