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
        
        let configuration = URLSessionConfiguration.background(withIdentifier: "com.craigrachel.Datapulter.background")
        configuration.allowsCellularAccess = false
        configuration.waitsForConnectivity = true
        
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        
    }
    
    //MARK: Public methods
    
    public func upload(_ urlrequest: URLRequest,_ fileURL: URL) -> URLSessionTask {
        
        let task = session.uploadTask(with: urlrequest, fromFile: fileURL)
        activeTasks.insert(task)
        task.resume()
        
        
        DispatchQueue.main.async {
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
        
        return task
    }
    
    public func cancel() {
        print("Client: cancel all tasks")
        for task in activeTasks {
            task.cancel()
        }
        activeTasks.removeAll()
    }
    
    public func suspend() {
        print("Client: suspend all tasks")
        for task in activeTasks {
            task.suspend()
        }
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
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
    }
    
}


//MARK: - URLSessionDataDelegate


extension Client: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        //AutoUpload.shared.hud(Float(totalBytesSent), Float(totalBytesExpectedToSend))
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("Client: task \(dataTask.taskIdentifier) -> didReceiveData")
        
        // downcast for access to statusCode
        guard let httpResponse = dataTask.response as? HTTPURLResponse else { return }
        
        AutoUpload.shared.handler(data, httpResponse, dataTask)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {

        print("Client: task \(task.taskIdentifier) -> didCompleteWithError")
        
        activeTasks.remove(task)
        print("Client: task \(task.taskIdentifier) -> removed from activeTasks.")
        
        if let error = error {
            // not a server error. client-side errors only ("unable to resolve the hostname or connect to the host")
            print("Client: task \(task.taskIdentifier) -> \(error.localizedDescription)")
        }
        
        // downcast for access to statusCode
        guard let httpResponse = task.response as? HTTPURLResponse else { return }
        
        print("Client: task \(task.taskIdentifier) -> STATUS \(httpResponse.statusCode)")
    }
    
}
