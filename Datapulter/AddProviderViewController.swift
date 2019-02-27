//
//  AddProviderViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Eureka

class AddProviderViewController: FormViewController, UITextFieldDelegate {
    
    //MARK: Properties
    var provider: Provider?

    @IBOutlet weak var saveProvider: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        

        
        form +++ Section()
            <<< ActionSheetRow<String>("actionsProvider") {
                $0.title = "Pick Provider"
                $0.selectorTitle = "Pick Provider"
                $0.options = ["Amazon S3","Backblaze B2","DigitalOcean Spaces"]
                $0.value = "Backblaze B2"    // initially selected
            }
            <<< AccountRow("tagKeyID"){ row in
                row.title = "Key ID"
                row.placeholder = "Your account key ID"
                row.add(rule: RuleRequired())
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Backblaze B2"
                    }
                    return false
                }
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
            }
            <<< PasswordRow("tagKey"){ row in
                row.title = "Key"
                row.placeholder = "Your key"
                row.add(rule: RuleRequired())
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Backblaze B2"
                    }
                    return false
                }
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
            }
            <<< AccountRow("tagBucket"){ row in
                row.title = "Bucket"
                row.placeholder = "Your unique bucket name"
                row.add(rule: RuleRequired())
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Backblaze B2"
                    }
                    return false
                }
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            +++ Section("OPTIONS")
            <<< SwitchRow("tagVersions"){ row in
                row.title = "Versions"
                row.value = true
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Backblaze B2"
                    }
                    return false
                }
                }
            <<< SwitchRow("tagHardDelete"){ row in
                row.title = "Hard Delete"
                row.value = false
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
    
    
    
    // This method lets you configure a view controller before it's presented.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        
        
        // Configure the destination view controller only when the save button is pressed.
        guard let button = sender as? UIBarButtonItem, button === saveProvider else {
            os_log("The save button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }
        

    }
    

    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
}

