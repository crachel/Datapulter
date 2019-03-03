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
//typealias Path = String
//typealias AuthorizationToken = String
/*
enum Method {
    case get, post, put, patch, delete
}*/

enum HttpMethod {
    static let post = "POST"
    static let get = "GET"
}

struct UploadObject<T> {
    let asset: PHAsset
    let urlPoolObject: T
}

/*
struct UploadObject2 {
    let asset: PHAsset
    let urlPoolObject: Data
}

// MARK: Endpoint
struct Endpoint {
    let method: Method
    let path: Path
    let queryItems: [URLQueryItem]
}*/

enum APIError: Error {
    case requestFailed
    case jsonConversionFailure
    case invalidData
    case responseUnsuccessful
    case jsonParsingFailure
    var localizedDescription: String {
        switch self {
        case .requestFailed: return "Request Failed"
        case .invalidData: return "Invalid Data"
        case .responseUnsuccessful: return "Response Unsuccessful"
        case .jsonParsingFailure: return "JSON Parsing Failure"
        case .jsonConversionFailure: return "JSON Conversion Failure"
        }
    }
}
