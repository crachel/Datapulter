//
//  B2Types.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/5/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

struct AuthorizeAccountResponse: Codable {
    var absoluteMinimumPartSize: Int64
    var accountId: String
    struct Allowed: Codable {
        var capabilities: [String]
        var bucketId: String?
        var bucketName: String?
        var namePrefix: String?
    }
    var apiUrl: String
    var authorizationToken: String
    var downloadUrl: String
    var recommendedPartSize: Int64
    let allowed: Allowed
}

struct Bucket: Codable {
    var accountId: String
    var bucketId: String
    var bucketInfo: [String: String]?
    var bucketName: String
    var bucketType: String
    var corsRules: CorsRules?
    var lifecycleRules: [String]
    var revision: Int?
    
    private enum CodingKeys: String, CodingKey {
        case accountId
        case bucketId
        case bucketInfo
        case bucketName
        case bucketType
        case corsRules
        case lifecycleRules
        case revision
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try container.decode(String.self, forKey: .accountId)
        bucketId = try container.decode(String.self, forKey: .bucketId)
        bucketName = try container.decode(String.self, forKey: .bucketName)
        bucketType = try container.decode(String.self, forKey: .bucketType)
        corsRules? = try container.decode(CorsRules.self, forKey: .corsRules)
        lifecycleRules = try container.decode([String].self, forKey: .lifecycleRules)
        revision? = try container.decode(Int.self, forKey: .revision)
        
        bucketInfo = [String: String]()
        let subContainer = try container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: .bucketInfo)
        for key in subContainer.allKeys {
            bucketInfo?[key.stringValue] = try subContainer.decode(String.self, forKey: key)
        }
        
    }
}

struct CorsRules: Codable {
    var corsRuleName: String
    var allowedOrigins: [String]
    var allowedOperations: [String]
    var allowedHeaders: [String]?
    var exposeHeaders: [String]?
    var maxAgeSeconds: Int
}

struct ListBucketsResponse: Codable {
    var buckets: [Bucket]
}

struct ListBucketsRequest: Codable {
    var accountId: String
    var bucketName: String?
}

struct GetUploadURLResponse: Codable {
    var bucketId: String
    var uploadUrl: URL
    var authorizationToken: String
}

struct GetUploadURLRequest: Codable {
    var bucketId: String
}

struct JSONError: Codable {
    var status: Int
    var code: String
    var message: String
}

struct UploadFileResponse: Codable {
    var accountId: String
    var action: String?
    var bucketId: String
    var contentLength: Int64
    var contentSha1: String
    var contentType: String
    var fileId: String
    var fileName: String
    var uploadTimestamp: String?
    let fileInfo: [String: String]?
    
    private enum CodingKeys: String, CodingKey {
        case accountId
        case action
        case bucketId
        case contentLength
        case contentSha1
        case contentType
        case fileId
        case fileName
        case uploadTimestamp
        case fileInfo
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accountId = try container.decode(String.self, forKey: .accountId)
        action? = try container.decode(String.self, forKey: .action)
        bucketId = try container.decode(String.self, forKey: .bucketId)
        contentLength = try container.decode(Int64.self, forKey: .contentLength)
        contentSha1 = try container.decode(String.self, forKey: .contentSha1)
        contentType = try container.decode(String.self, forKey: .contentType)
        fileId = try container.decode(String.self, forKey: .fileId)
        fileName = try container.decode(String.self, forKey: .fileName)
        uploadTimestamp? = try container.decode(String.self, forKey: .uploadTimestamp)
        
        fileInfo = [String: String]()
        let subContainer = try container.nestedContainer(keyedBy: GenericCodingKeys.self, forKey: .fileInfo)
        for key in subContainer.allKeys {
            fileInfo?[key.stringValue] = try subContainer.decode(String.self, forKey: key)
        }
        
    }
}

struct GenericCodingKeys: CodingKey {
    var intValue: Int?
    var stringValue: String
    
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
    init?(stringValue: String) { self.stringValue = stringValue }
    
    static func makeKey(name: String) -> GenericCodingKeys {
        return GenericCodingKeys(stringValue: name)!
    }
}
