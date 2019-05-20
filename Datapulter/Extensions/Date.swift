//
//  Date.swift
//  Datapulter
//
//  Created by Craig Rachel on 2/6/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

extension Date {
    var millisecondsSince1970:Int64 {
        return Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds / 1000))
    }
    
    static func getFormattedDate() -> String{
        let formatter = ISO8601DateFormatter()
        
        formatter.formatOptions = [.withYear, .withMonth, .withDay]
        
        return formatter.string(from: Date())
    }
    
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        
        formatter.formatOptions = [.withYear, .withMonth, .withDay, .withTime, .withTimeZone]

        return formatter.string(from: self)
    }
}
