//
//  Endpoint.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/30/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

struct Endpoint {
    var components = URLComponents()
    
    var method: String?
    
    init(components: URLComponents, method: String? = HTTPMethod.post) {
        self.components = components
        self.method = method
        
        if(components.scheme == nil) {
            self.components.scheme = "https"
        }
    }
    
    init(scheme: String? = "https",
         path: String,
         method: String? = HTTPMethod.post) {
        self.components.scheme = scheme
        self.components.path = path
        self.method = method
    }
}
