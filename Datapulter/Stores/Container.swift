//
//  Container.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/9/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import CloudKit
import os.log

class Container {
    
    var publicDatabase: CKDatabase
    var privateDatabase: CKDatabase
    
    init() {
        
        let container = CKContainer.default()
        
        publicDatabase  = container.publicCloudDatabase
        privateDatabase = container.privateCloudDatabase
        
    }
    
    public func getRecord(_ keyName: String,_ recordType: String, completion:@escaping (_ record: [CKRecord]?) -> Void) {
        
        let predicate = NSPredicate(format: "keyName == %@", keyName)
        
        let query = CKQuery(recordType: recordType, predicate: predicate)
        
        publicDatabase.perform(query, inZoneWith: nil) { record, error in
            if let record = record {
                completion(record)
            } else if let error = error {
                os_log("%@", log: .container, type: .error, error.localizedDescription)
            }
        }
    }
}
