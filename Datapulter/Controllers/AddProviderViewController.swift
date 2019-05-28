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
    
    /*
     
     /*row.hidden = Condition.function(["actionsProvider"])
     { form in
     if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
     return row.value != "Backblaze B2"
     }
     return false
     }*/
     
     
     
     */
    
    //MARK: Properties
    var provider: Provider?

    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view, typically from a nib.
        form +++ Section()
            <<< ActionSheetRow<String>("actionsProvider") {
                    $0.title = "Provider"
                    $0.selectorTitle = "Pick Provider"
                    $0.options = ["Backblaze B2","Amazon S3","Datapulter Managed"]
                    $0.value = "Backblaze B2"    // initially selected
                }
            <<< AccountRow("tagName") { row in
                    row.title = "Remote Name"
                    row.placeholder = "\"My Remote Storage\""
                    row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            <<< AccountRow("tagHostName") { row in
                row.title = "Host Name"
                row.placeholder = "s3.amazonaws.com"
                row.add(rule: RuleRequired())
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Amazon S3"
                    }
                    return false
                }
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            <<< AccountRow("tagKeyID") { row in
                    row.title = "Key ID"
                    row.placeholder = "Your account key ID"
                    row.add(rule: RuleRequired())
                }.cellUpdate { cell, _ in
                    cell.textField.delegate = self
                }
            <<< PasswordRow("tagKey") { row in
                    row.title = "Key"
                    row.placeholder = "Your key"
                    row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            <<< AccountRow("tagBucket") { row in
                    row.title = "Bucket"
                    row.placeholder = "Your unique bucket name"
                    row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            <<< AccountRow("tagPrefix") { row in
                    row.title = "Prefix"
                    row.placeholder = "my/directory"
                    row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            /*
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
                }*/
    }
    
    //MARK: Navigation
    
    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        return true
    }
    
    // This method lets you configure a view controller before it's presented.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
    }
    
    //MARK: Actions

    @IBAction func saveButton(_ sender: Any) {
        if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
            
            let alert = UIAlertController(title: "Alert", message: "Failed to authorize account.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
            
            let valuesDictionary = form.values()
            
            if(row.value == "Backblaze B2") {
                
                //provider = B2(name: valuesDictionary["tagName"] as! String, account: "000bd9db9a329de0000000002", key: "K0002N7fDPHf/MaFFITLUinf8//4qqc", bucket: "datapulter", versions: true, harddelete: false, accountId: "bd9db9a329de", bucketId: "db9d09bd1b19ba3362790d1e", remoteFileList: [:], filePrefix: "simulator")
                
                provider = B2(name: valuesDictionary["tagName"] as! String, account: "000bd9db9a329de0000000002", key: "K0002N7fDPHf/MaFFITLUinf8//4qqc", bucket: "datapulter", accountId: "bd9db9a329de", bucketId: "db9d09bd1b19ba3362790d1e", remoteFileList: [:], filePrefix: "simulator")
                
                provider?.authorize().then { _ in
                //provider?.authorizeAccount().then { _ in
                    self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
                }.catch { _ in
                    self.present(alert, animated: true, completion: nil)
                }
                
            } else if (row.value == "Amazon S3") {
                //provider = S3(name: "s3", accessKeyID: "AKIAZ46WPMYAAYVDOW5H", secretAccessKey: "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", bucket: "datapulter", regionName: "us-west-2", hostName: "s3.amazonaws.com",  remoteFileList: [:])
                
                //provider = S3(name: "s3", accessKeyID: "7UMVJ6E6SAVLPCXF3C2B", secretAccessKey: "Ag6DmIiBeE1qs0mLqLL6LjgbhHaAM8IjD/88Hu8HwC4", bucket: "datapulter", regionName: "sfo2", hostName: "sfo2.digitaloceanspaces.com", remoteFileList: [:])
                
                self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
            }
        }
        
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
