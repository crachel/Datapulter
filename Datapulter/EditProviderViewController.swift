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

        // Downcast then show appropriate form
        if let backblazeb2 = provider as? b2 {
            form
            +++ Section("REQUIRED")
            <<< TextRow("tagKeyID"){ row in
                row.title = "Key ID"
                row.placeholder = "Your account key ID"
                row.value = backblazeb2.Account
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< PasswordRow("tagKey"){ row in
                row.title = "Key"
                row.placeholder = "Your key"
                row.value = backblazeb2.Key
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< TextRow("tagBucket"){ row in
                row.title = "Bucket"
                row.placeholder = "Your unique bucket name"
                row.value = backblazeb2.Bucket
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            +++ Section(header: "OPTIONS", footer: "Ignore unless you know what these mean.")
            <<< SwitchRow("tagVersions"){ row in
                row.title = "Versions"
                row.value = backblazeb2.Versions
            } .onChange { row in
                backblazeb2.Versions = row.value!
            }
            <<< SwitchRow("tagHardDelete"){ row in
                row.title = "Hard Delete"
                row.value = backblazeb2.HardDelete
            } .onChange { row in
                backblazeb2.HardDelete = row.value!
            }
        } // else if let s3-compliant = provider as? s3
    }
        
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Disable the Save button while editing.
        save.isEnabled = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        let valuesDictionary = form.values() // retrieve all form values
        for (_, value) in valuesDictionary {
            if(value == nil) {
                // user left a form value blank
                save.isEnabled = false
                break
            } else {
                save.isEnabled = true
            }
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
