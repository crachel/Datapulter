//
//  KeychainHelper.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/24/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Security

class KeychainHelper {
    
    public static func set(account: String, value: String,  server: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: account,
                                    kSecValueData as String: value.data(using: .utf8) as Any,
                                    kSecAttrServer as String: server]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            os_log("set error", log: .keychainhelper, type: .error)
            return false
        }
        return true
    }
    
    public static func update(account: String, value: String,  server: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: account]
        let attributes: [String: Any] = [kSecValueData as String: value.data(using: .utf8) as Any,
                                         kSecAttrServer as String: server]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        guard status == errSecSuccess else {
            return set(account: account, value: value, server: server)
        }
        
        return true
    }
    
    public static func get(account: String) -> [String : Any]? {
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: account,
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecReturnData as String: true]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status != errSecItemNotFound else {
            os_log("nothing found", log: .keychainhelper, type: .error)
            return nil
        }
        guard status == errSecSuccess else {
            os_log("get error", log: .keychainhelper, type: .error)
            return nil
        }
        
        guard let result = item as? [String : Any] else {
            os_log("unexpected nil returned", log: .keychainhelper, type: .error)
            return nil
        }
        return result
        //return String(data: result as! Data, encoding: .utf8)
    }
    
    public static func delete(account: String) -> Bool {
        let query:[String : Any] = [kSecClass as String: kSecClassInternetPassword,
                                    kSecAttrAccount as String: account]
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess else {
            os_log("keychain delete error", log: .keychainhelper, type: .error)
            return false
        }
        return true
    }
}
