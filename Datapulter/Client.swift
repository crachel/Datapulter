//
//  Client.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/3/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
//import Promises

class Client: NSObject {
    
    //MARK: Properties
    
    var backgroundCompletionHandler: (() -> Void)?
    
    static let maxActiveTasks = 5
    
    private var session: URLSession!
    private var activeTaskIds: Set<Int>?
    
    
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
    
    //MARK: Public methods
    
    public func upload(_ urlrequest: URLRequest,_ data: Data) -> Int {
        
        let task = session.uploadTask(with: urlrequest, from: data)
        activeTaskIds?.insert(task.taskIdentifier)
        task.resume()
        
        return (task.taskIdentifier)
        
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
        
        //let httpResponse = dataTask.response as? HTTPURLResponse
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
        
        let httpResponse = task.response as? HTTPURLResponse
        
        activeTaskIds?.remove(task.taskIdentifier)
        
        //let something = task.originalRequest?.allHTTPHeaderFields
        
        if let error = error {
            // handle failure here
            //
            
            print("\(error.localizedDescription)")
        } else {
            
            if (httpResponse?.statusCode == 401 || httpResponse?.statusCode == 503) {
                print("urlSession -> STATUS 401 or 503")
                // prob unauthorized
                // get new url & token.
                // get image data somehow
                // AutoUpload.reauthorizeRequest(newRequest, data)
                
                var newRequest = task.originalRequest
                newRequest?.setValue("newgoodtoken", forHTTPHeaderField: "Authorization")
                
            } else if (httpResponse?.statusCode == 200) {
                
                print("urlSession -> STATUS 200")
                if ((activeTaskIds?.count)! < Client.maxActiveTasks) {
                 // add more tasks, if any exist
                }
            } else {
                print("urlSession -> UNHANDLED ERROR")
                // very bad
            }
        }
    }
    
}


