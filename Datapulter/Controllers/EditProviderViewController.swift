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
 
        if let backblaze = provider as? B2 {
            form
            +++ Section("REQUIRED")
            <<< AccountRow("tagName"){ row in
                row.title = "Name"
                row.placeholder = "My Backlaze B2 Remote"
                row.value = backblaze.name
                row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
            }
            <<< AccountRow("tagKeyID"){ row in
                row.title = "Key ID"
                row.placeholder = "Your account key ID"
                row.value = backblaze.account
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< PasswordRow("tagKey"){ row in
                row.title = "Key"
                row.placeholder = "Required"
                row.value = backblaze.key
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< AccountRow("tagBucket"){ row in
                row.title = "Bucket"
                row.placeholder = "Your unique bucket name"
                row.value = backblaze.bucket
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< AccountRow("tagPrefix"){ row in
                row.title = "Prefix"
                row.placeholder = "my/directory/"
                row.value = backblaze.filePrefix
                row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
            }
                /*
            +++ Section("OPTIONS")
            <<< SwitchRow("tagVersions"){ row in
                row.title = "Versions"
                row.value = backblaze.versions
            }.onChange { row in
                if(self.formValidated()){
                    self.save.isEnabled = true
                }
            }
            <<< SwitchRow("tagHardDelete"){ row in
                row.title = "Hard Delete"
                row.value = backblaze.harddelete
            }.onChange { row in
                if(self.formValidated()){
                    self.save.isEnabled = true
                }
            }*/
        } else if let s3 = provider as? S3 {
            form
            +++ Section("REQUIRED")
            <<< AccountRow("tagName"){ row in
                row.title = "Name"
                row.value = s3.name
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                    cell.textField.delegate = self
            }
            <<< URLRow("tagHostName") { row in
                row.title = "Host Name"
                row.value = URL(string:s3.hostName)
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< IntRow("tagPort") { row in
                row.title = "Port"
                row.value = s3.port
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< AccountRow("tagRegionName") { row in
                row.title = "Region"
                row.value = s3.regionName
                row.add(rule: RuleRequired())
            }.cellUpdate { cell, row in
                cell.textField.delegate = self
            }
            <<< ActionSheetRow<String>("tagStorageClass") {
                $0.title = "Storage Class"
                $0.selectorTitle = "Pick Storage Class"
                $0.options = ["STANDARD","STANDARD_IA","INTELLIGENT_TIERING","ONEZONE_IA","GLACIER","DEEP_ARCHIVE"]
                $0.value = s3.storageClass
            }.onChange { row in
                self.save.isEnabled = true
            }
            
                <<< AccountRow("tagKeyID") { row in
                    row.title = "Key ID"
                    row.value = s3.accessKeyID
                    row.add(rule: RuleRequired())
                    }.cellUpdate { cell, _ in
                        cell.textField.delegate = self
                }
                <<< PasswordRow("tagKey") { row in
                    row.title = "Key"
                    row.value = s3.secretAccessKey
                    row.add(rule: RuleRequired())
                    }.cellUpdate { cell, row in
                        cell.textField.delegate = self
                }
                <<< AccountRow("tagBucket") { row in
                    row.title = "Bucket"
                    row.value = s3.bucket
                    row.add(rule: RuleRequired())
                    }.cellUpdate { cell, row in
                        cell.textField.delegate = self
                }
                <<< AccountRow("tagPrefix") { row in
                    row.title = "Prefix"
                    row.value = s3.filePrefix
                    row.add(rule: RuleRequired())
                    }.cellUpdate { cell, row in
                        cell.textField.delegate = self
                }
                +++ Section("OPTIONS")
                <<< SwitchRow("tagVirtual"){ row in
                    row.title = "Virtual Hosting"
                    row.value = s3.useVirtual
                }
                <<< SwitchRow("tagScheme"){ row in
                    row.title = "SSL (HTTPS)"
                    row.value = (s3.scheme == "https" || s3.scheme == "HTTPS")
            }
            
            ////
        }
    }
        
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Disable the Save button while editing.
        save.isEnabled = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if(formValidated()){
            save.isEnabled = true
        }
    }
    
    func formValidated() -> Bool {
        for (_, value) in form.values() {
            if(value == nil) {
                // user left a form value blank
                return false
            }
        }
        return true
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            
        case "unwindToProviderList": // Save button has been clicked
            let valuesDictionary = form.values()
            if let backblaze = provider as? B2 {
                backblaze.name = valuesDictionary["tagName"] as! String
                backblaze.account = valuesDictionary["tagKeyID"] as! String
                backblaze.key = valuesDictionary["tagKey"] as! String
                backblaze.bucket = valuesDictionary["tagBucket"] as! String
                //backblaze.versions = valuesDictionary["tagVersions"] as! Bool
                //backblaze.harddelete = valuesDictionary["tagHardDelete"] as! Bool
                backblaze.filePrefix = valuesDictionary["tagPrefix"] as! String
            } // else if let s3
            os_log("Unwinding to provider list.", log: OSLog.default, type: .debug)
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }


    /*
    // Call unwindToProviderList when user clicks back button
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        /*
        if self.isMovingFromParent {
            self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
        }*/
     if self.isMovingFromParent {
        os_log("Back button clicked", log: OSLog.default, type: .debug)
     }
    }

    override func willMove(toParent parent: UIViewController?)
    {
        super.willMove(toParent: parent)
        if parent == nil
        {
            os_log("Back button clicked", log: OSLog.default, type: .debug)
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
