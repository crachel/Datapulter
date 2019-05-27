//
//  ProviderManager.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/24/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import os.log

final class ProviderManager {
    
    //MARK: Properties
    
    var providers = [Provider]()
    
    //MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("providers")
    
    //MARK: Singleton
    
    static let shared = ProviderManager()
    
    //MARK: Public Methods
    
    public func saveProviders() {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: providers, requiringSecureCoding: false)
            try data.write(to: ProviderManager.ArchiveURL)
        } catch {
            os_log("failed to save providers", log: .providerManager, type: .error)
        }
    }
    
    public func loadProviders() -> [Provider]? {
        let fullPath = ProviderManager.ArchiveURL
        if let nsData = NSData(contentsOf: fullPath) {
            do {
                let data = Data(referencing:nsData)
                
                if let loadedProviders = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Array<Provider> {
                    return loadedProviders
                }
            } catch {
                os_log("failed to load providers", log: .providerManager, type: .error)
                return nil
            }
        }
        return nil
    }
    
}
