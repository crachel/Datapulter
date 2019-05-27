//
//  XMLHelper.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/26/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

class XMLHelper: NSObject {
    var parser: XMLParser
    
    let recordKey: String
    let dictionaryKeys: Set<String>
    
    var results: [[String:String]]?
    var currentDictionary: [String: String]?
    var currentValue: String?
    
    init(data: Data,recordKey: String, dictionaryKeys: Set<String>) {
        
        self.parser = XMLParser(data: data)
        
        self.recordKey = recordKey
        self.dictionaryKeys = dictionaryKeys
    }
    
    func go() -> [[String:String]]? {
        self.parser.delegate = self
        
        if parser.parse() {
            if let results = results {
                return results
            } else {
                return nil
            }
        } else {
            return nil
        }
    }
}

extension XMLHelper: XMLParserDelegate {
    // initialize results structure
    
    func parserDidStartDocument(_ parser: XMLParser) {
        results = []
    }
    
    // start element
    //
    // - If we're starting a "record" create the dictionary that will hold the results
    // - If we're starting one of our dictionary keys, initialize `currentValue` (otherwise leave `nil`)
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName == recordKey {
            currentDictionary = [:]
        } else if dictionaryKeys.contains(elementName) {
            currentValue = ""
        }
    }
    
    // found characters
    //
    // - If this is an element we care about, append those characters.
    // - If `currentValue` still `nil`, then do nothing.
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue? += string
    }
    
    // end element
    //
    // - If we're at the end of the whole dictionary, then save that dictionary in our array
    // - If we're at the end of an element that belongs in the dictionary, then save that value in the dictionary
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == recordKey {
            results!.append(currentDictionary!)
            currentDictionary = nil
        } else if dictionaryKeys.contains(elementName) {
            currentDictionary![elementName] = currentValue
            currentValue = nil
        }
    }
    
    // Just in case, if there's an error, report it. (We don't want to fly blind here.)
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print(parseError)
        
        currentValue = nil
        currentDictionary = nil
        results = nil
    }
}
