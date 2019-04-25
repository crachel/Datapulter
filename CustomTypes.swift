//
//  CustomTypes.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/24/19.
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
}

struct JSONError: Codable {
    var status: Int
    var code: String
    var message: String
}

/*
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