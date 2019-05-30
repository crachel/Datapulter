//
//  Constants.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/6/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

typealias NetworkCompletionHandler = (Data?, URLResponse?, Error?) -> Void

struct GenericCodingKeys: CodingKey {
    var intValue: Int?
    var stringValue: String
    
    init?(intValue: Int) { self.intValue = intValue; self.stringValue = "\(intValue)" }
    init?(stringValue: String) { self.stringValue = stringValue }
    
    static func makeKey(name: String) -> GenericCodingKeys {
        return GenericCodingKeys(stringValue: name)!
    }
}

enum HTTPMethod {
    static let post = "POST"
    static let get = "GET"
    static let put = "PUT"
}

struct JSONError: Codable, Error {
    var status: Int
    var code: String
    var message: String
}


