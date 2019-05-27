//
//  Meta.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/27/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

protocol Meta: Codable {
    associatedtype Element
    static func metatype(for element: Element) -> Self
    var type: Decodable.Type { get }
    
    init?(rawValue: String)
    var rawValue: String { get }
}

struct MetaArray<M: Meta>: Codable, ExpressibleByArrayLiteral {
    
    var array: [M.Element]
    
    init(array: [M.Element]) {
        self.array = array
    }
    
    init(arrayLiteral elements: M.Element...) {
        self.array = elements
    }
    
    struct ElementKey: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        
        var intValue: Int? { return nil }
        init?(intValue: Int) { return nil }
    }
    
    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        
        var elements: [M.Element] = []
        while !container.isAtEnd {
            let nested = try container.nestedContainer(keyedBy: ElementKey.self)
            guard let key = nested.allKeys.first else { continue }
            let metatype = M(rawValue: key.stringValue)
            let superDecoder = try nested.superDecoder(forKey: key)
            let object = try metatype?.type.init(from: superDecoder)
            if let element = object as? M.Element {
                elements.append(element)
            }
        }
        array = elements
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        try array.forEach { object in
            var nested = container.nestedContainer(keyedBy: ElementKey.self)
            let metatype = M.metatype(for: object)
            if let key = ElementKey(stringValue: metatype.rawValue) {
                let superEncoder = nested.superEncoder(forKey: key)
                let encodable = object as? Encodable
                try encodable?.encode(to: superEncoder)
            }
        }
    }
}
