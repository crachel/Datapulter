//
//  EditProviderViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/8/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Eureka

class EditProviderViewController: FormViewController, UITextFieldDelegate {
    
    //MARK: Properties
    @IBOutlet weak var save: UIBarButtonItem!
    var provider: Provider?

    override func viewDidLoad() {
        super.viewDidLoad()
 
        if let backblaze = provider as? b2 {
            form
            +++ Section("REQUIRED")
            <<< TextRow("tagKeyID"){ row in
                row.title = "Key ID"
                row.placeholder = "Your account key ID"
                row.value = backblaze.account
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< PasswordRow("tagKey"){ row in
                row.title = "Key"
                row.placeholder = "Your key"
                row.value = backblaze.key
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< TextRow("tagBucket"){ row in
                row.title = "Bucket"
                row.placeholder = "Your unique bucket name"
                row.value = backblaze.bucket
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            +++ Section("OPTIONS")
            <<< SwitchRow("tagVersions"){ row in
                row.title = "Versions"
                row.value = backblaze.versions
            }.onChange { row in
                //backblazeb2.versions = row.value!
            }
            <<< SwitchRow("tagHardDelete"){ row in
                row.title = "Hard Delete"
                row.value = backblaze.harddelete
            }.onChange { row in
                //backblazeb2.harddelete = row.value!
            }
        } // else if let s3-compliant = provider as? s3
    }
        
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Disable the Save button while editing.
        save.isEnabled = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        var formValidated = true
        let valuesDictionary = form.values() // retrieve all form values
        for (_, value) in valuesDictionary {
            if(value == nil) {
                // user left a form value blank
                formValidated = false
                break
            }
        }
        if(formValidated){
            save.isEnabled = true
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            
        case "unwindToProviderList": // Save button has been clicked
            if (provider as? b2) != nil {
                os_log("Unwinding to provider list.", log: OSLog.default, type: .debug)
            }
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }


    /*
    // Call unwindToProviderList when user clicks back button
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if self.isMovingFromParent {
            self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
        }
    }*/
    

 /*
    // MARK: - Navigation
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        /*if let owningNavigationController = navigationController {
            owningNavigationController.popViewController(animated: true)
        }*/
        //dismiss(animated: true, completion: nil)
    }*/
    
    /*
    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
        super.prepare(for: segue, sender: sender)
        
        
        // Configure the destination view controller only when the save button is pressed.
        guard let button = sender as? UIBarButtonItem, button === saveButton else {
            os_log("The save button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }
        

    }
    */

}
