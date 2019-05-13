//
//  OSLog.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/12/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!
    
    static let autoupload     = OSLog(subsystem: subsystem, category: "AutoUpload")
    static let b2             = OSLog(subsystem: subsystem, category: "Provider.B2")
    static let apiclient      = OSLog(subsystem: subsystem, category: "APIClient")
    static let keychainhelper = OSLog(subsystem: subsystem, category: "KeychainHelper")
    static let utility        = OSLog(subsystem: subsystem, category: "Utility")
    static let container      = OSLog(subsystem: subsystem, category: "Container")
}
