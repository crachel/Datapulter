//
//  FileSystem.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/7/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

class FileSystem {
    public static func getTemporaryURL(_ filename: String) -> URL? {
        return URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(filename)
    }
    
    public static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
}
