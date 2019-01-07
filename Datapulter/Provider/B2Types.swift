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
    struct BucketInfo: Codable {
        
    }
    var bucketName: String
    var bucketType: String
    var corsRules: [String]?
    var lifecycleRules: [String]
    var revision: Int?
    let bucketInfo: BucketInfo
}

struct ListBucketsResponse: Codable {
    var buckets: [Bucket]
}

struct GetUploadURLResponse: Codable {
    var bucketId: String
    var uploadUrl: URL
    var authorizationToken: String
}

struct UploadFileResponse: Codable {
    var accountId: String
    var action: String?
    var bucketId: String
    var contentLength: Int64
    var contentSha1: String
    var contentType: String
    var fileId: String
    struct FileInfo: Codable {
        
    }
    var fileName: String
    var uploadTimestamp: String?
    let fileInfo: FileInfo?
}
