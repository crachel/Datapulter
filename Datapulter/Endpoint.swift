//
//  Endpoint.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/12/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos

// MARK: Defines
typealias Path = String
typealias AuthorizationToken = String

enum Method {
    case get, post, put, patch, delete
}

enum HttpMethod {
    static let post = "POST"
    static let get = "GET"
}

struct UploadObject2 {
    let asset: PHAsset
    let uploadUrl: URL
    let uploadToken: AuthorizationToken
}

struct UploadObject<T> {
    let asset: PHAsset
    let urlPoolObject: T
}

// MARK: Endpoint
struct Endpoint {
    let method: Method
    let path: Path
    let queryItems: [URLQueryItem]
}
