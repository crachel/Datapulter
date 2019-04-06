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
import Promises

class AddProviderViewController: FormViewController, UITextFieldDelegate {
    
    //MARK: Properties
    var provider: Provider?

    @IBOutlet weak var saveProvider: UIBarButtonItem!
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
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
            <<< AccountRow("tagName"){ row in
                row.title = "Remote Name"
                row.placeholder = "\"My Backblaze B2 Remote\""
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
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return true
    }
    
    // This method lets you configure a view controller before it's presented.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        
        // Configure the destination view controller only when the save button is pressed.
        guard let button = sender as? UIBarButtonItem, button === saveButton else {
            os_log("The save button was not pressed, cancelling", log: OSLog.default, type: .debug)
            return
        }
        
        print("Done preparing for segue.")

    }

    @IBAction func saveButton(_ sender: Any) {
        if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
            /*
            let alert = UIAlertController(title: "My Alert", message: "This is an alert.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel action"), style: .cancel, handler: { _ in
                NSLog("The \"Cancel\" alert occured.")
            }))
            self.present(alert, animated: true, completion: nil)*/
            let valuesDictionary = form.values()
            
            if(row.value == "Backblaze B2") {
                //let valuesDictionary = form.values()
                //print(valuesDictionary["tagKeyID"] as! String)
                //"K0002N7fDPHf/MaFFITLUinf8//4qqc"
                provider = B2(name: valuesDictionary["tagName"] as! String, account: "000bd9db9a329de0000000002", key: "K0002N7fDPHf/MaFFITLUinf8//4qqc", bucket: "datapulter", versions: true, harddelete: false, accountId: "bd9db9a329de", bucketId: "db9d09bd1b19ba3362790d1e", remoteFileList: [:], assetsToUpload: [])
                provider?.login().then { success in
                    if (success) {
                        print("provider successfully created.")
                        self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
                        
                    } else {
                        // alert user of bad log in
                    }
                }
            }
        }
        
    }
    
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
}

