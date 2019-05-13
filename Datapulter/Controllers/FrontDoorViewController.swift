//
//  FrontDoorViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/5/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

class FrontDoorViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Load any saved providers
        if let savedProviders = AutoUpload.shared.loadProviders() {
            AutoUpload.shared.providers += savedProviders
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if(AutoUpload.shared.providers.isEmpty) {
            performSegue(withIdentifier: "showTable", sender: nil)
        } else {
            performSegue(withIdentifier: "showTable", sender: nil)
        }
    }
}
