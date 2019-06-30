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
import WLEmptyState

class ProviderTableViewController: UITableViewController, WLEmptyStateDataSource {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.emptyStateDataSource = self // WLEmptyState
        
        // Display an Edit button in the navigation bar for this view controller.
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        //tableView.tableFooterView = UIView()
        
        AutoUpload.shared.start()
    
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
        return ProviderManager.shared.providers.providers.array.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Table view cells are reused and should be dequeued using a cell identifier.
        let cellIdentifier = "ProvidersTableViewCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? ProviderTableViewCell else {
            fatalError("The dequeued cell is not an instance of ProvidersTableViewCell")
        }
        
        // Fetches the appropriate provider for the data source layout.
        let provider = ProviderManager.shared.providers.providers.array[indexPath.row]

        // Configure the cell...
    
        cell.providerLabel.text = provider.name
        cell.hudLabel.text = "App initialized."
        
        cell.ringView.innerRingColor = .gray
        cell.ringView.outerRingColor = .black
        cell.ringView.outerRingWidth = 16
        cell.ringView.innerRingWidth = 12
        cell.ringView.style = .ontop
        
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
            // Remove any UserDefaults
            if let appDomain = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: appDomain)
            }
            
            let provider = ProviderManager.shared.providers.providers.array[indexPath.row]
            
            // Do any provider-specific preparation before deleting
            provider.willDelete()
    
            // Cancel all APIClient tasks
            APIClient.shared.cancel()
            
            // Delete the row from the data source
            ProviderManager.shared.providers.providers.array.remove(at: indexPath.row)
            
            ProviderManager.shared.saveProviders()
            
            tableView.deleteRows(at: [indexPath], with: .fade)
            
            self.navigationItem.rightBarButtonItem?.isEnabled = true
            
            tableView.reloadData()
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }

    //MARK: - Navigation

    // Do a little preparation before navigation
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
            
            let selectedProvider = ProviderManager.shared.providers.providers.array[indexPath.row]
            
            providerDetailViewController.provider = selectedProvider

            os_log("Editing a provider.", log: OSLog.default, type: .debug)
        
        case "showLogin":
            
            os_log("Showing the login controller.", log: OSLog.default, type: .debug)
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    //MARK: WLEmptyState Methods
    
    func imageForEmptyDataSet() -> UIImage? {
        return UIImage(named: "Icon Grey")
    }
    
    func titleForEmptyDataSet() -> NSAttributedString {
        let title = NSAttributedString(string: "Datapulter", attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)])
        return title
    }
    
    func descriptionForEmptyDataSet() -> NSAttributedString {
        let title = NSAttributedString(string: "Add a provider above to start.", attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
        return title
    }
    
    //MARK: Actions
    
    @IBAction func unwindToProviderList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? EditProviderViewController, let provider = sourceViewController.provider {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                // Update an existing provider.
                ProviderManager.shared.providers.providers.array[selectedIndexPath.row] = provider
                
                
                tableView.reloadRows(at: [selectedIndexPath], with: .none)
            }
        } else if let sourceViewController = sender.source as? AddProviderViewController, let provider = sourceViewController.provider {
            // Add a new provider.
            ProviderManager.shared.providers.providers.array += [provider]
            
            self.navigationItem.rightBarButtonItem?.isEnabled = false
            
            tableView.reloadData()
        }
        
        ProviderManager.shared.saveProviders()
        
        AutoUpload.shared.start()
    }
}

// MARK: PHPhotoLibraryChangeObserver

extension ProviderTableViewController: PHPhotoLibraryChangeObserver {

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        
        DispatchQueue.main.sync {
            let fetchResultChangeDetails = changeInstance.changeDetails(for: AutoUpload.shared.assets)
            
            guard (fetchResultChangeDetails) != nil else {
                
                os_log("no change in fetchResultChangeDetails", log: OSLog.default, type: .info)
                
                return;
                
            }
            
            os_log("photoLibraryDidChange", log: OSLog.default, type: .info)
    
            AutoUpload.shared.assets = (fetchResultChangeDetails?.fetchResultAfterChanges)!
            
            AutoUpload.shared.start()
        }
    }
}
