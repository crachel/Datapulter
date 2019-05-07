//
//  String.swift
//  Datapulter
//
//  Created by Craig Rachel on 5/7/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

extension String {
    func addingSuffixIfNeeded(_ suffix: String) -> String {
        guard !hasSuffix(suffix) else {
            return self
        }
        
        return appending(suffix)
    }
}
