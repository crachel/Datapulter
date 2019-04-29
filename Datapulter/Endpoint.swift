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
