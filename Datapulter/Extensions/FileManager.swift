//
//  FileManager.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/10/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import os.log

extension FileManager {
    func clearTemporaryDirectory() {
        do {
            let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            let temporaryDirectory = try contentsOfDirectory(atPath: temporaryDirectoryURL.path)
            
            try temporaryDirectory.forEach { file in
                let fileURL = temporaryDirectoryURL.appendingPathComponent(file)
                try removeItem(atPath: fileURL.path)
            }
        } catch {
            os_log("%@", log: OSLog.default, type: .error, error.localizedDescription)
        }
    }
}
