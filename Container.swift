//
//  Container.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/9/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import CloudKit

enum ManagedKey: String {
    case accountId
    case applicationKey
    case applicationKeyId
    case bucketId
    case capabilities
    case keyName
    case namePrefix
}

class Container {

    init() {
        let container = CKContainer.default()
        //var publicDatabase = container.publicCloudDatabase
        
        let record = CKRecord(recordType: "Managed")
        record[.applicationKey] = "applicationKey" as CKRecordValue
        
        //privateDatabase.fetch(withRecordID: <#T##CKRecord.ID#>, completionHandler: <#T##(CKRecord?, Error?) -> Void#>)
        if let containerIdentifier = container.containerIdentifier {
            print(containerIdentifier)
        }
    }
}

extension CKRecord {
    
    subscript(key: ManagedKey) -> Any? {
        get {
            return self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue as? CKRecordValue
        }
    }
    
}
