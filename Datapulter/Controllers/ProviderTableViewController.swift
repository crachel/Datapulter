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
        
        tableView.emptyStateDataSource = self
        
        // Display an Edit button in the navigation bar for this view controller.
        self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        tableView.tableFooterView = UIView()
        
        // Load any saved providers
       // if let savedProviders = loadProviders() {
         //   AutoUpload.shared.providers += savedProviders
            
            if(AutoUpload.shared.providers.isEmpty) {
                //performSegue(withIdentifier: "showLogin", sender: nil)
                //let test = UIImage(named: "backblazeb2")
                //tableView.backgroundView = UIImageView(image: test)
                
            } else {
                //tableView.backgroundColor = UIColor.clear
                AutoUpload.shared.start()
            }
        
            // Register to receive photo library change messages
            PHPhotoLibrary.shared().register(self)
       // }
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
       
    }
    
    deinit {
        
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        
    }

    //MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
            /*
             
             delete userdefaults and keychain stuff. any other cleanup/deinit
             Provider.willRemove()
             
             */
            // Delete the row from the data source
            AutoUpload.shared.providers.remove(at: indexPath.row)
            
            //saveProviders()
            AutoUpload.shared.saveProviders()
            
            tableView.deleteRows(at: [indexPath], with: .fade)
            
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
            
            let selectedProvider = AutoUpload.shared.providers[indexPath.row]
            providerDetailViewController.provider = selectedProvider

            os_log("Editing a provider.", log: OSLog.default, type: .debug)
        
        case "showLogin":
            
            os_log("Showing the login controller.", log: OSLog.default, type: .debug)
            
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }
    
    func imageForEmptyDataSet() -> UIImage? {
        //return UIImage(named: "AppIcon")
        return UIImage(named: "Icon Grey")
    }
    
    func titleForEmptyDataSet() -> NSAttributedString {
        let title = NSAttributedString(string: "Datapulter", attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .headline)])
        return title
    }
    
    func descriptionForEmptyDataSet() -> NSAttributedString {
        let title = NSAttributedString(string: "Add a provider above.", attributes: [NSAttributedString.Key.font: UIFont.preferredFont(forTextStyle: .caption1)])
        return title
    }
    
    //MARK: Private Methods
    
    /*
    private func saveProviders() {
        let fullPath = getDocumentsDirectory().appendingPathComponent("providers")
        
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: AutoUpload.shared.providers, requiringSecureCoding: false)
            try data.write(to: fullPath)
            os_log("Providers successfully saved.", log: OSLog.default, type: .debug)
        } catch {
            os_log("Failed to save providers...", log: OSLog.default, type: .error)
        }
    }*/
    
    private func loadProviders() -> [Provider]?  {
        let fullPath = getDocumentsDirectory().appendingPathComponent("providers")
        if let nsData = NSData(contentsOf: fullPath) {
            do {
                let data = Data(referencing:nsData)
                
                if let loadedProviders = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? Array<Provider> {
                    return loadedProviders
                }
            } catch {
                print("Couldn't read file.")
                return nil
            }
        }
        return nil
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    //MARK: Actions
    
    @IBAction func unwindToProviderList(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? EditProviderViewController, let provider = sourceViewController.provider {
            
            if let selectedIndexPath = tableView.indexPathForSelectedRow {
                // Update an existing provider.
                AutoUpload.shared.providers[selectedIndexPath.row] = provider
                tableView.reloadRows(at: [selectedIndexPath], with: .none)
            }
        } else if let sourceViewController = sender.source as? AddProviderViewController, let provider = sourceViewController.provider {
            // Add a new provider.
            AutoUpload.shared.providers += [provider]
            tableView.reloadData()
        }
        
        // Save the providers.
        //saveProviders()
        AutoUpload.shared.saveProviders()
        
        print("unwindToProviderList: starting AutoUpload")
        AutoUpload.shared.start()
    }
}

// MARK: PHPhotoLibraryChangeObserver

extension ProviderTableViewController: PHPhotoLibraryChangeObserver {

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        /*
        if (APIClient.shared.isActive()) {
            return
        }*/
        
        DispatchQueue.main.sync {
            let fetchResultChangeDetails = changeInstance.changeDetails(for: AutoUpload.shared.assets)
            
            guard (fetchResultChangeDetails) != nil else {
                
                print("No change in fetchResultChangeDetails")
                
                return;
                
            }
            
            print("Contains changes")
            
            AutoUpload.shared.assets = (fetchResultChangeDetails?.fetchResultAfterChanges)!
            
            AutoUpload.shared.start()
            
            //let insertedObjects = fetchResultChangeDetails?.insertedObjects
            
            print("autoupload assets\(String(describing: AutoUpload.shared.assets.count))")
            
            let removedObjects = fetchResultChangeDetails?.removedObjects
            
            print("removedObjects\(String(describing: removedObjects?.count))")
            
        }
        
    }
    
}
