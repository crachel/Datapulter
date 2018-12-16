//
//  AddProviderViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Eureka

class AddProviderViewController: FormViewController {
    
    //MARK: Properties

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        

        
        form +++ Section()
            <<< ActionSheetRow<String>("actionsProvider") {
                $0.title = "Provider"
                $0.selectorTitle = "Pick a provider"
                $0.options = ["Amazon S3","Backblaze B2","DigitalOcean Spaces"]
                $0.value = "Backblaze B2"    // initially selected
            }
            <<< AccountRow(){ row in
                row.title = "Text Row"
                row.placeholder = "Enter text here"
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Backblaze B2"
                    }
                    return false
                }
            } 
            <<< AccountRow(){ row in
                row.title = "Phone Row"
                row.placeholder = "And numbers here"
                row.add(rule: RuleRequired())
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Backblaze B2"
                    }
                    return false
                }
            }
    }
    
    //MARK: Navigation
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
}

