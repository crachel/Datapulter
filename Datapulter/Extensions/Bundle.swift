//
//  Bundle.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/7/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
}
