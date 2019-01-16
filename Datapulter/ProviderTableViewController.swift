//
//  ProviderTableViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import os.log
import Photos
import UICircularProgressRing

class ProviderTableViewController: UITableViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Display an Edit button in the navigation bar for this view controller.
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        // Load any saved providers
        if let savedProviders = loadProviders() {
           AutoUpload.shared.providers += savedProviders
        }
        
        //loadSampleProviders()

        DispatchQueue.global(qos: .userInitiated).async {
            AutoUpload.shared.start()
        }
        
        // Register to receive photo library change messages
        PHPhotoLibrary.shared().register(self)
        
    }
    
    deinit {
        
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        
    }

    //MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        //return providers.count
        return AutoUpload.shared.providers.count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ProvidersTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ProviderTableViewCell else {
            fatalError("The dequeued cell is not an instance of ProvidersTableViewCell")
        }
        
        // Fetches the appropriate provider for the data source layout.
        let provider = AutoUpload.shared.providers[indexPath.row]

        // Configure the cell...
    
        cell.providerLabel.text = provider.name
        
        cell.ringView.innerRingColor = provider.innerRing
        cell.ringView.outerRingWidth = 10
        cell.ringView.innerRingWidth = 10
        cell.ringView.ringStyle = .ontop
        cell.ringView.showsValueKnob = true
        cell.ringView.value = 77
        
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
            AutoUpload.shared.providers.remove(at: indexPath.row)
            
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
            
            //let selectedProvider = providers[indexPath.row]
            let selectedProvider = AutoUpload.shared.providers[indexPath.row]
            providerDetailViewController.provider = selectedProvider


            os_log("Editing a provider.", log: OSLog.default, type: .debug)
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    //MARK: Private Methods
    

    
    private func saveProviders() {
        //let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(providers, toFile: Provider.ArchiveURL.path)
        let isSuccessfulSave = NSKeyedArchiver.archiveRootObject(AutoUpload.shared.providers, toFile: Provider.ArchiveURL.path)
        
        /*
        do {
            try NSKeyedArchiver.archivedData(withRootObject: AutoUpload.shared.providers, requiringSecureCoding: true)
        } catch {
            print(error)
        }*/
        
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
        let provider1 = B2(name: "My Backblaze B2 Remote", account: "000bd9db9a329de0000000002", key: "K0002N7fDPHf/MaFFITLUinf8//4qqc", bucket: "datapulter", versions: true, harddelete: false, accountId: "bd9db9a329de", bucketId: "db9d09bd1b19ba3362790d1e")
        //let provider2 = B2(name: "My Second Backblaze B2 Remote", account: "123456ABCDE", key: "S3CR3TK3Y", bucket: "myotherbucket", versions: false, harddelete: true, accountId: "temp", bucketId: "temp")

        //providers += [provider1, provider2]
        AutoUpload.shared.providers += [provider1]
    }
    
    //MARK: Actions
    
    @IBAction func unwindToProviderList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? EditProviderViewController, let provider = sourceViewController.provider {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                // Update an existing provider.
                
                AutoUpload.shared.providers[selectedIndexPath.row] = provider
                tableView.reloadRows(at: [selectedIndexPath], with: .none)
            }
        } // add else for AddProviderViewController
        
        // Save the providers.
        saveProviders()
    }
    
}

// MARK: PHPhotoLibraryChangeObserver

extension ProviderTableViewController: PHPhotoLibraryChangeObserver {
    
    
    
    func photoLibraryDidChange(_ changeInstance: PHChange) {
  
        DispatchQueue.main.sync {
            let fetchResultChangeDetails = changeInstance.changeDetails(for: AutoUpload.shared.assets)
            
            guard (fetchResultChangeDetails) != nil else {
                
                print("No change in fetchResultChangeDetails")
                
                return;
                
            }
            
            print("Contains changes")
            
            AutoUpload.shared.assets = (fetchResultChangeDetails?.fetchResultAfterChanges)!
            
            //let insertedObjects = fetchResultChangeDetails?.insertedObjects
            
            print("autoupload assets\(String(describing: AutoUpload.shared.assets.count))")
            
            let removedObjects = fetchResultChangeDetails?.removedObjects
            
            print("removedObjects\(String(describing: removedObjects?.count))")
            
        }
        
    }
    
}
