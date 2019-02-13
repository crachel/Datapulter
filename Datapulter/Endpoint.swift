//
//  Endpoint.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/12/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit


// MARK: Defines
typealias Path = String

enum Method {
    case get, post, put, patch, delete
}


// MARK: Endpoint
struct Endpoint {
    let method: Method
    let path: Path
    let queryItems: [URLQueryItem]
}
