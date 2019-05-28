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
    
    struct ProviderArray: Codable, Identifiable {
        typealias RawIdentifier = UUID
        
        let id: ID
        
        var providers: MetaArray<ProviderMetatype>
        
        init() {
            id = ID.init(rawValue: UUID())
            self.providers = []
        }
    }
    
    var providers = ProviderArray()
    
    //MARK: Archiving Paths
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let ArchiveURL = DocumentsDirectory.appendingPathComponent("providers")
    
    //MARK: Singleton
    
    static let shared = ProviderManager()
    
    //MARK: Public Methods
    
    public func saveProviders() {
        do {
            let data = try JSONEncoder().encode(providers)
            
            try data.write(to: ProviderManager.ArchiveURL)
        } catch {
            os_log("failed to save providers: %@", log: .providerManager, type: .error, error.localizedDescription)
        }
    }
    
    public func loadProviders() -> ProviderArray? {
        if let nsData = NSData(contentsOf: ProviderManager.ArchiveURL) {
            do {
                let data = Data(referencing: nsData)
                let array = try JSONDecoder().decode(ProviderArray.self, from: data)
                
                return array
            } catch {
                os_log("failed to load providers: %@", log: .providerManager, type: .error, error.localizedDescription)
                return nil
            }
        }
        return nil
    }
    
}
