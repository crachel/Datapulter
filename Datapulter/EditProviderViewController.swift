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

class EditProviderViewController: FormViewController {
    
    //MARK: Properties
    @IBOutlet weak var save: UIBarButtonItem!
    var provider: Provider?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        form +++ Section("REQUIRED")
            <<< TextRow("keyIDTag"){ row in
                row.title = "Key ID"
                row.placeholder = "Your account key ID"
                row.value = self.provider?.Account
                }.onChange{ row in
                    guard let value = row.value else { fatalError("Cannot get Key ID value from row") }
                    self.save.isEnabled = true
                    self.provider?.Account = value
                }
            <<< PasswordRow("keyTag"){
                $0.title = "Key"
                $0.placeholder = "Your key"
            }
            <<< TextRow("bucketTag"){
                $0.title = "Bucket"
                $0.placeholder = "Your unique bucket name"
            }
            +++ Section("OPTIONS")
            <<< SwitchRow("versionTag"){
                $0.title = "Versions"
            }
            <<< SwitchRow("hardDeleteTag"){
                $0.title = "Hard Delete"
            }
            <<< IntRow("chunkSizeTag"){
                $0.title = "Chunk Size"
            }
            <<< IntRow("uploadCutoffTag"){
                $0.title = "Upload Cutoff"
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
        dismiss(animated: true, completion: nil)
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
