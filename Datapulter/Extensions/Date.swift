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
    
    static func getFormattedDate(_ dateFormat: String) -> String{
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US")
        dateFormatter.dateFormat = dateFormat // This formate is input formated .
        
        return(dateFormatter.string(from: Date()))
    }
    
    var iso8601: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
