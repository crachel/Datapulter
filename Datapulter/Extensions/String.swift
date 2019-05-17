//
//  String.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/7/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import CommonCrypto

extension String {
    func addingSuffixIfNeeded(_ suffix: String) -> String {
        guard !hasSuffix(suffix) else {
            return self
        }
        
        return appending(suffix)
    }
    
    func sha256() -> String? {
        guard let data = self.data(using: .utf8) else {
            return nil
        }
        
        return data.sha256
    }
    
    /*
    func hmac_sha256(key: String) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), key, key.count, self, self.count, &digest)
        let data = Data(digest)
        
        //return data.map { String(format: "%02hhx", $0) }.joined()
        //return data.map { String(format: "%02x", $0) }.joined()
        
        return data
    }*/
    
    func hmac_sha256(key: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        key.withUnsafeBytes { rawBufferPointer in
            let rawPtr = rawBufferPointer.baseAddress!
            // ... use `rawPtr` ...
            
            CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), rawPtr, key.count, self, self.count, &digest)
        }
    
        let data = Data(digest)
        
        return data
    }
}
