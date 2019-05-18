//
//  Data+Crypto.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/11/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import CommonCrypto

extension Data {
    
    public var sha1: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        
        _ = withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_SHA1(bytes.baseAddress, CC_LONG(count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public var sha256: String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        _ = withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_SHA256(bytes.baseAddress, CC_LONG(count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    public var hex: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}
