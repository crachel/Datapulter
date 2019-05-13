//
//  CKRecord.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/12/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import CloudKit

extension CKRecord {
    
    subscript(key: Managed.ManagedApplicationKey) -> Any? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue as? CKRecordValue
        }
    }
    
}
