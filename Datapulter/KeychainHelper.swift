//
//  KeychainHelper.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/24/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Security

class KeychainHelper {
    public static func set(value: String, forKey: String) -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: forKey,
                                    kSecValueData as String: value.data(using: .utf8) as Any]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            print("keychain set error")
            return false
        }
        return true
    }
    
    public static func get(forKey: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: forKey,
                                    kSecReturnData as String: kCFBooleanTrue]
        var item: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            print("keychain get error")
            return nil
        }
        
        guard let result = item else {
            print("Unexpected nil returned from keychain")
            return nil
        }
        return String(data: result as! Data, encoding: .utf8)
    }
    
    public static func delete(forKey: String) -> Bool {
        let query:[String : Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: forKey]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            print("keychain delete error: \(SecItemDelete(query as CFDictionary))")
            return false
        }
        return true
    }
}
