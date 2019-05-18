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
    
    func hmac_sha256(key: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        
        key.withUnsafeBytes { rawBufferPointer in
            if let rawPtr = rawBufferPointer.baseAddress {
                CCHmac(CCHmacAlgorithm(kCCHmacAlgSHA256), rawPtr, key.count, self, self.count, &digest)
            }
        }
        
        return Data(digest)
    }
}
