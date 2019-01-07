//
//  Client.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/3/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Promises

class Client: NSObject {
    
    //MARK: Properties
    
    var backgroundCompletionHandler: (() -> Void)?
    
    private var session: URLSession!
    private var activeTaskIds: NSMutableSet?
    
    let decoder = JSONDecoder()
    
    //MARK: Singleton
    
    static let shared = Client()
    
    //MARK: Initialization
    
    private override init() {
        
        super.init()
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.background")
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = true
        
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
    }
    
    func upload(_ urlrequest: URLRequest,_ data: Data) {
        session.uploadTask(with: urlrequest, from: data).resume()
    }
        
    public func test(_ urlrequest: URLRequest) {
        
        session.dataTask(with: urlrequest)
    }
    
}


//MARK: - URLSessionDelegate


extension Client: URLSessionDelegate {
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletionHandler?()
            self.backgroundCompletionHandler = nil
        }
    }
    
}


//MARK: - URLSessionDataDelegate


extension Client: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // this SHOULD be the response json
        print("urlSession -> didReceiveData")
        //let response = try! decoder.decode(UploadFileResponse.self, from: data)
        do {
            let json = try JSONSerialization.jsonObject(with: data)
            
            print("\(json)")
            // do something with json
        } catch {
            print("\(error.localizedDescription)")
        }

    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("urlSession -> didCompleteWithError")
        
        if let error = error {
            // handle failure here
            print("\(error.localizedDescription)")
        } else {
            /* remove from activeTaskIds
                make sure still logged in
                start another task
             */
        }
        
        
        /*
 // other stuff
 [activeTaskIds removeObject:@([task taskIdentifier])]
 
 if ([activeTaskIds count] < NUMBER) {
 // add more tasks
 }*/
    }
    
}


