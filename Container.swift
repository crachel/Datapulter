//
//  Container.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/9/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import CloudKit

class Container {
    init() {
        let container = CKContainer.default()
        //var privateDatabase = container.privateCloudDatabase
        
        
        //privateDatabase.fetch(withRecordID: <#T##CKRecord.ID#>, completionHandler: <#T##(CKRecord?, Error?) -> Void#>)
        if let containerIdentifier = container.containerIdentifier {
            print(containerIdentifier)
        }
    }
}
