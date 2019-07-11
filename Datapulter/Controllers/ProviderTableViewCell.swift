//
//  ProviderTableViewCell.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import UICircularProgressRing

class ProviderTableViewCell: UITableViewCell {

    //MARK: Properties
    @IBOutlet weak var ringView: UICircularProgressRing!
    @IBOutlet weak var providerLabel: UILabel!
    @IBOutlet weak var progressLine: UIProgressView!
    @IBOutlet weak var hudLabel: UILabel!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var resetButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    @IBAction func pressed(_ sender: Any) {
        APIClient.shared.cancel()
    }

    @IBAction func paused(_ sender: Any) {
        APIClient.shared.suspend()
    }
    
    @IBAction func started(_ sender: Any) {
        APIClient.shared.resume()
    }
    
    @IBAction func reset(_ sender: Any) {
        APIClient.shared.cancel()
        
        AutoUpload.shared.start()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
}
