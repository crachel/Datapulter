//
//  Endpoint.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/12/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos

//typealias Parameters = [String: Any]
//typealias Path = String

struct Endpoint {
    var method, path, scheme: String
    
    init(method: String = HttpMethod.post,
         path: String,
         scheme: String = "https") {
        self.method = method
        self.path = path
        self.scheme = scheme
    }
}

enum HttpMethod {
    static let post = "POST"
    static let get = "GET"
}

struct UploadObject<T> {
    let asset: PHAsset
    let urlPoolObject: T
}

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
