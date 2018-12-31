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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display an Edit button in the navigation bar for this view controller.
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        // Load any saved providers, otherwise load sample data.
        if let savedProviders = loadProviders() {
            providers += savedProviders
        }
        
        //loadSampleProviders()
        
        DispatchQueue.global(qos: .userInitiated).async {
            AutoUpload.shared.start(providers: self.providers)
        }
        
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
        
        provider.cell = cell

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
