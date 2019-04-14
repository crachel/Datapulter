//
//  Endpoint.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/12/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Photos

struct Endpoint {
    var components = URLComponents()
    
    var method: String?
    
    init(components: URLComponents, method: String = HTTPMethod.post) {
        self.components = components
        self.method = method
    }
    
    init(scheme: String? = "https",
         path: String,
        method: String? = HTTPMethod.post) {
        self.components.scheme = scheme
        self.components.path = path
        self.method = method
    }
}

enum HTTPMethod {
    static let post = "POST"
    static let get = "GET"
}

/*
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
}*/
