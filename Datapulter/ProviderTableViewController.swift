//
//  ProviderTableViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import UICircularProgressRing

class ProviderTableViewController: UITableViewController {
    
    //MARK: Properties
    var providers = [Provider]()
    var autoupload = AutoUpload()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        //let test = B2.Router.list_buckets(apiUrl: "https://api000.backblazeb2.com", accountId: "bd9db9a329de", accountAuthorizationToken: "4_000bd9db9a329de0000000002_018900ab_63f319_acct_5ubYrxE1BKReFalPbvom-LX6p1s=", bucketName: "datapulter")
        //let test = B2.Router.get_upload_url(apiUrl: "https://api000.backblazeb2.com", accountAuthorizationToken: "4_000bd9db9a329de0000000002_018900ab_63f319_acct_5ubYrxE1BKReFalPbvom-LX6p1s=", bucketId: "db9d09bd1b19ba3362790d1e")
        //let login = B2.Router.authorize_account(accountId: "000bd9db9a329de0000000002", applicationKey: "K0002N7fDPHf/MaFFITLUinf8//4qqc")
        
        
        /*
        //print(autoupload.manager?.request(test))
        autoupload.session.request(test).responseJSON {
            response in
            print(response)
        }*/
        
        /*
        autoupload.request(urlrequest: try! login.asURLRequest()).then { json -> Promise<JSON> in
            return self.autoupload.request(urlrequest: try! B2.Router.get_upload_url(apiUrl: json["apiUrl"] as! String, accountAuthorizationToken: json["accountAuthorizationToken"] as! String, bucketId: json["bucketId"] as! String).asURLRequest())
            }.catch { error in
                // handle error
        }
    */
 
   
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        
        // Load any saved providers, otherwise load sample data.
        if let savedProviders = loadProviders() {
            providers += savedProviders
        }
        else {
            // Load the sample data.
            //loadSampleProviders()
        }
        //loadSampleProviders()
        //let indexPath = IndexPath(item: 0, section: 0)
        //let cell = tableView.cellForRow(at: 0) as! ProviderTableViewCell
        //var cell = tableView.cellForRow(at: indexPath) as! ProviderTableViewCell
        //cell.ringView.value = 55
        /*
        DispatchQueue.main.async {
        if let cell = self.tableView.cellForRow(at: IndexPath(row: 0,
                                                                section: 0)) as? ProviderTableViewCell {
            cell.updateDisplay(value: 55)
        }
        }
 */
        
        autoupload.start(providers: providers)
        
        
    }

    //MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return providers.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ProvidersTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ProviderTableViewCell else {
            fatalError("The dequeued cell is not an instance of ProvidersTableViewCell")
        }
        
        // Fetches the appropriate provider for the data source layout.
        let provider = providers[indexPath.row]

        // Configure the cell...
    
        cell.providerLabel.text = provider.name
        
        cell.ringView.innerRingColor = provider.innerRing
        cell.ringView.outerRingWidth = 10
        cell.ringView.innerRingWidth = 10
        cell.ringView.ringStyle = .ontop
        cell.ringView.showsValueKnob = true
        cell.ringView.valueIndicator = ""
        cell.ringView.value = UICircularProgressRing.ProgressValue(provider.assetsToUpload.count)
        provider.cell = cell
        
        /*
        cell.ringView.startProgress(to: 25, duration: 6) {
            // This is called when it's finished animating!
            DispatchQueue.main.async {
                // We can animate the ring back to another value here, and it does so fluidly
                cell.ringView.startProgress(to: 100, duration: 2)
            }
        }
 */


        return cell
    }
    

    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    

    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            providers.remove(at: indexPath.row)
            saveProviders()
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    
    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */
    

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    
    //MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            
        case "AddItem":
            os_log("Adding a new provider.", log: OSLog.default, type: .debug)
            
        case "EditItem":
            guard let providerDetailViewController = segue.destination as? EditProviderViewController else {
                fatalError("Unexpected destination: \(segue.destination)")
            }
            
            guard let selectedProviderCell = sender as? ProviderTableViewCell else {
                fatalError("Unexpected sender: \(String(describing: sender))")
            }
            
            guard let indexPath = tableView.indexPath(for: selectedProviderCell) else {
                fatalError("The selected cell is not being displayed by the table")
            }
            
            let selectedProvider = providers[indexPath.row]
            providerDetailViewController.provider = selectedProvider


            os_log("Editing a provider.", log: OSLog.default, type: .debug)
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    //MARK: Private Methods
    
    private func saveProviders() {
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(providers, toFile: Provider.ArchiveURL.path)
        if isSuccessfulSave {
            os_log("Providers successfully saved.", log: OSLog.default, type: .debug)
        } else {
            os_log("Failed to save providers...", log: OSLog.default, type: .error)
        }
    }
    
    private func loadProviders() -> [Provider]?  {
        return NSKeyedUnarchiver.unarchiveObject(withFile: Provider.ArchiveURL.path) as? [Provider]
    }
    
    private func loadSampleProviders() {
        let provider1 = B2(name: "My Backblaze B2 Remote", account: "123456ABCDE", key: "S3CR3TK3Y", bucket: "mybucket", versions: true, harddelete: false)
        let provider2 = B2(name: "My Second Backblaze B2 Remote", account: "123456ABCDE", key: "S3CR3TK3Y", bucket: "myotherbucket", versions: false, harddelete: true)

        providers += [provider1, provider2]
    }
    
    //MARK: Actions
    
    @IBAction func unwindToProviderList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? EditProviderViewController, let provider = sourceViewController.provider {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                // Update an existing provider.
                providers[selectedIndexPath.row] = provider
                tableView.reloadRows(at: [selectedIndexPath], with: .none)
            }
        } // add else for AddProviderViewController
        
        // Save the providers.
        saveProviders()
    }
    
}
