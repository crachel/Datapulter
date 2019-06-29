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

    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        form +++ Section()
            <<< ActionSheetRow<String>("actionsProvider") {
                    $0.title = "Provider"
                    $0.selectorTitle = "Pick Provider"
                    $0.options = ["Backblaze B2","Amazon S3"]
                    $0.value = "Backblaze B2"    // initially selected
                }
            <<< AccountRow("tagName") { row in
                    row.title = "Remote Name"
                    row.placeholder = "My Remote Storage"
                    row.add(rule: RuleRequired())
                }.cellUpdate { cell, row in
                    cell.textField.delegate = self
                }
            <<< URLRow("tagHostName") { row in
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
            <<< IntRow("tagPort") { row in
                row.title = "Port"
                row.value = 443
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
            <<< AccountRow("tagRegionName") { row in
                row.title = "Region"
                row.placeholder = "us-east-1"
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
            <<< ActionSheetRow<String>("tagStorageClass") {
                $0.title = "Storage Class"
                $0.selectorTitle = "Pick Storage Class"
                $0.options = ["STANDARD","STANDARD_IA","INTELLIGENT_TIERING","ONEZONE_IA","GLACIER","DEEP_ARCHIVE"]
                $0.value = "STANDARD"    // initially selected
                $0.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Amazon S3"
                    }
                    return false
                }
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
            +++ Section("OPTIONS") { row in
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Amazon S3"
                    }
                    return false
                }
            }
            <<< SwitchRow("tagVirtual"){ row in
                row.title = "Virtual Hosting"
                row.value = true
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Amazon S3"
                    }
                    return false
                }
                }
            <<< SwitchRow("tagScheme"){ row in
                row.title = "SSL (HTTPS)"
                row.value = true
                row.hidden = Condition.function(["actionsProvider"])
                { form in
                    if let row = form.rowBy(tag: "actionsProvider") as? ActionSheetRow<String> {
                        return row.value != "Amazon S3"
                    }
                    return false
                }
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
                
                provider = B2(name: valuesDictionary["tagName"] as! String, account: "000bd9db9a329de0000000002", key: "K0002N7fDPHf/MaFFITLUinf8//4qqc", bucket: "datapulter", accountId: "bd9db9a329de", bucketId: "db9d09bd1b19ba3362790d1e", remoteFileList: [:], filePrefix: "iphone6splus")
                
                provider?.authorize().then { _ in
                //provider?.authorizeAccount().then { _ in
                    self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
                }.catch { _ in
                    self.present(alert, animated: true, completion: nil)
                }
                
            } else if (row.value == "Amazon S3") {
                
                provider = S3(name: valuesDictionary["tagName"] as! String, accessKeyID: "AKIAZ46WPMYAAYVDOW5H", secretAccessKey: "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", bucket: "datapulter", regionName: "us-west-2", hostName: "s3.amazonaws.com",  remoteFileList: [:], filePrefix: "simulator", storageClass: valuesDictionary["tagStorageClass"] as! String, useVirtual: true, port: 443, scheme: "https")
                
                //provider = S3(name: valuesDictionary["tagName"] as! String, accessKeyID: "7UMVJ6E6SAVLPCXF3C2B", secretAccessKey: "Ag6DmIiBeE1qs0mLqLL6LjgbhHaAM8IjD/88Hu8HwC4", bucket: "datapulter", regionName: "sfo2", hostName: "sfo2.digitaloceanspaces.com", remoteFileList: [:], filePrefix: "iphone6splus", storageClass: valuesDictionary["tagStorageClass"] as! String, useVirtual: true, port: 443, scheme: "https")
                
                //provider = S3(name: valuesDictionary["tagName"] as! String, accessKeyID: "crachel", secretAccessKey: "Vjg4S3R5AW", bucket: "datapulter", regionName: "us-east-1", hostName: "192.168.1.186",  remoteFileList: [:], filePrefix: "iphone6splus", storageClass: valuesDictionary["tagStorageClass"] as! String, useVirtual: false, port: 9000, scheme: "http")
                
                provider?.authorize().then { _ in
                    //provider?.authorizeAccount().then { _ in
                    self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
                }.catch { _ in
                    self.present(alert, animated: true, completion: nil)
                }
                
                //self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
            }
        }
        
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
