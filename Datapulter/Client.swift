//
//  Client.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/3/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

class Client: NSObject {
    
    //MARK: Properties
    
    var backgroundCompletionHandler: (() -> Void)?
    
    public var session: URLSession!
    public var activeTasks = Set<URLSessionTask>()
    
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
    
    public func upload(_ urlrequest: URLRequest,_ fileURL: URL) -> URLSessionTask {
        
        let task = session.uploadTask(with: urlrequest, fromFile: fileURL)
        activeTasks.insert(task)
        task.resume()
        
        return task
    }
    
    public func isActive() -> Bool {
        return (activeTasks.count > 0)
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
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        //AutoUpload.shared.hud(Float(totalBytesSent), Float(totalBytesExpectedToSend))
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("urlSession -> didReceiveData")
        
        // downcast for access to statusCode
        guard let httpResponse = dataTask.response as? HTTPURLResponse else { return }
        
        AutoUpload.shared.handler(data, httpResponse, dataTask)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("urlSession -> didCompleteWithError")
        
        // downcast for access to statusCode
        guard let httpResponse = task.response as? HTTPURLResponse else { return }
        
        activeTasks.remove(task)
        
        if let error = error {
            print("(didCompleteWithError) \(error.localizedDescription)")
        } else {
            
            if (httpResponse.statusCode == 401) {
                print("urlSession -> STATUS 401")
      
            } else if (httpResponse.statusCode == 503) {
                
                print("urlSession -> STATUS 503")
                
            } else if (httpResponse.statusCode == 200) {
                
                print("urlSession -> STATUS 200")
                print("task \(task.taskIdentifier) finished successfully.")
                
            } else {
                
                print("urlSession -> UNHANDLED ERROR")
            }
        }
    }
    
}
