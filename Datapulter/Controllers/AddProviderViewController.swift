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
    
    struct Tags {
        static let s3 = "Amazon S3"
        static let b2 = "Backblaze B2"
        
        static let actionsProvider = "actionsProvider"
        static let name = "name"
        static let hostName = "hostName"
        static let port = "port"
        static let regionName = "regionName"
        static let storageClass = "storageClass"
        static let keyID = "keyID"
        static let key = "key"
        static let bucket = "bucket"
        static let prefix = "prefix"
        static let virtual = "virtual"
        static let scheme = "scheme"
    }

    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        self.navigationItem.rightBarButtonItem?.isEnabled = false
        
        form +++ Section()
        <<< ActionSheetRow<String>(Tags.actionsProvider) { row in
            row.title = "Provider"
            row.selectorTitle = "Pick Provider"
            row.options = [Tags.b2,Tags.s3]
            row.value = Tags.b2
        }
        <<< AccountRow(Tags.name) { row in
            row.title = "Remote Name"
            row.placeholder = "My Remote Storage"
            row.add(rule: RuleRequired())
        }.cellUpdate { cell, _ in
            cell.textField.delegate = self
        }
        <<< AccountRow(Tags.hostName) { row in
            row.title = "Host Name"
            row.placeholder = "s3.amazonaws.com"
            row.add(rule: RuleRequired())
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }.cellUpdate { cell, row in
            cell.textField.delegate = self
            
            if !row.isValid {
                cell.titleLabel?.textColor = .red
            }
        }
        <<< IntRow(Tags.port) { row in
            row.title = "Port"
            row.value = 443
            row.add(rule: RuleRequired())
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }.cellUpdate { cell, _ in
            cell.textField.delegate = self
        }
        <<< AccountRow(Tags.regionName) { row in
            row.title = "Region"
            row.placeholder = "us-east-1"
            row.add(rule: RuleRequired())
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }.cellUpdate { cell, _ in
            cell.textField.delegate = self
        }
        <<< ActionSheetRow<String>(Tags.storageClass) { row in
            row.title = "Storage Class"
            row.selectorTitle = "Pick Storage Class"
            row.options = ["STANDARD","STANDARD_IA","INTELLIGENT_TIERING","ONEZONE_IA","GLACIER","DEEP_ARCHIVE"]
            row.value = "STANDARD"
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }
        <<< AccountRow(Tags.keyID) { row in
            row.title = "Key ID"
            row.placeholder = "Your account key ID"
            row.add(rule: RuleRequired())
        }.cellUpdate { cell, _ in
            cell.textField.delegate = self
        }
        <<< PasswordRow(Tags.key) { row in
            row.title = "Key"
            row.placeholder = "Your key"
            row.add(rule: RuleRequired())
        }.cellUpdate { cell, _ in
            cell.textField.delegate = self
        }
        <<< AccountRow(Tags.bucket) { row in
            row.title = "Bucket"
            row.placeholder = "Your unique bucket name"
            row.add(rule: RuleRequired())
        }.cellUpdate { cell, row in
            cell.textField.delegate = self
        }
        <<< AccountRow(Tags.prefix) { row in
            row.title = "Prefix"
            row.placeholder = "my/directory"
            row.add(rule: RuleRequired())
        }.cellUpdate { cell, row in
            cell.textField.delegate = self
        }
        +++ Section("OPTIONS") { row in
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }
        <<< SwitchRow(Tags.virtual) { row in
            row.title = "Virtual Hosting"
            row.value = true
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }
        <<< SwitchRow(Tags.scheme) { row in
            row.title = "SSL (HTTPS)"
            row.value = true
            row.hidden = Condition.function([Tags.actionsProvider]) { form in
                if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
                    return row.value != Tags.s3
                }
                return false
            }
        }
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Disable the Save button while editing.
        self.navigationItem.rightBarButtonItem?.isEnabled = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if(formValidated()){
            self.navigationItem.rightBarButtonItem?.isEnabled = true
        }
    }
    
    func formValidated() -> Bool {
        for (tag, value) in form.values() {
            if(value == nil && tag != Tags.prefix) {
                // user left a form value blank
                return false
            }
        }
        return true
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
        if let row = form.rowBy(tag: Tags.actionsProvider) as? ActionSheetRow<String> {
            
            let alert = UIAlertController(title: "Alert", message: "Failed to authorize account.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Default action"), style: .default, handler: { _ in
                NSLog("The \"OK\" alert occured.")
            }))
            
            let valuesDictionary = form.values()
            
            if(row.value == Tags.b2) {
                
                provider = B2(name: valuesDictionary[Tags.name] as! String,
                              account: valuesDictionary[Tags.keyID] as! String,
                              key: valuesDictionary[Tags.key] as! String,
                              bucket: valuesDictionary[Tags.bucket] as! String,
                              accountId: "",
                              bucketId: "",
                              remoteFileList: [:],
                              filePrefix: (valuesDictionary[Tags.prefix] as! String))
                
                provider?.authorize().then { _ in
                    self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
                }.catch { _ in
                    self.present(alert, animated: true, completion: nil)
                }
                
            } else if (row.value == Tags.s3) {
                
                var scheme: String
                
                if (valuesDictionary[Tags.scheme] as! Bool == true) {
                    scheme = "https"
                } else {
                    scheme = "http"
                }
                
                provider = S3(name: valuesDictionary[Tags.name] as! String,
                              accessKeyID: valuesDictionary[Tags.keyID] as! String,
                              secretAccessKey: valuesDictionary[Tags.key] as! String,
                              bucket: valuesDictionary[Tags.bucket] as! String,
                              regionName: valuesDictionary[Tags.regionName] as! String,
                              hostName: valuesDictionary[Tags.hostName] as! String,
                              remoteFileList: [:],
                              filePrefix: valuesDictionary[Tags.prefix] as? String,
                              storageClass: valuesDictionary[Tags.storageClass] as! String,
                              useVirtual: valuesDictionary[Tags.virtual] as! Bool,
                              port: valuesDictionary[Tags.port] as! Int,
                              scheme: scheme) // tagScheme
                
                provider?.authorize().then { _ in
                    self.performSegue(withIdentifier: "unwindToProviderList", sender: self)
                }.catch { error in
                    self.present(alert, animated: true, completion: nil)
                }
            }
        }
        
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
