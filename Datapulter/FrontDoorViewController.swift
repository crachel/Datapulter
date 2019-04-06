//
//  FrontDoorViewController.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/5/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

class FrontDoorViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        // Load any saved providers
        if let savedProviders = loadProviders() {
            AutoUpload.shared.providers += savedProviders
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        if(AutoUpload.shared.providers.isEmpty) {
            performSegue(withIdentifier: "showTable", sender: nil)
        } else {
            performSegue(withIdentifier: "showTable", sender: nil)
        }
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    //MARK: Private Methods
    
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

}
