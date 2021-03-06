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
            <<< AccountRow("tagHostName") { row in
                row.title = "Host Name"
                //row.value = URL(string:s3.hostName)
                row.value = s3.hostName
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
                    }.onChange { row in
                        self.save.isEnabled = true
                }
                <<< SwitchRow("tagScheme"){ row in
                    row.title = "SSL (HTTPS)"
                    row.value = (s3.scheme == "https" || s3.scheme == "HTTPS")
                    }.onChange { row in
                        self.save.isEnabled = true
                }
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
                backblaze.filePrefix = (valuesDictionary["tagPrefix"] as! String)
            } else if let s3 = provider as? S3 {
                s3.name = valuesDictionary["tagName"] as! String
                s3.hostName = valuesDictionary["tagHostName"] as! String //tagHostName
                s3.port = valuesDictionary["tagPort"] as! Int
                s3.regionName = valuesDictionary["tagRegionName"] as! String //tagRegionName
                s3.storageClass = valuesDictionary["tagStorageClass"] as! String
                s3.accessKeyID = valuesDictionary["tagKeyID"] as! String
                s3.secretAccessKey = valuesDictionary["tagKey"] as! String
                s3.bucket = valuesDictionary["tagBucket"] as! String
                s3.filePrefix = (valuesDictionary["tagPrefix"] as! String)
                s3.useVirtual = valuesDictionary["tagVirtual"] as! Bool
                
                if(valuesDictionary["tagScheme"] as! Bool == true) {
                    s3.scheme = "https"
                } else {
                    s3.scheme = "http"
                }
            }
            os_log("Unwinding to provider list.", log: OSLog.default, type: .debug)
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
}
