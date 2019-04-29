//
//  APIClient.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/27/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit

class APIClient: NSObject {
    
    //MARK: Properties
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = false
        return URLSession(configuration: configuration,
                          delegate: self, delegateQueue: nil)
    }()
    
    private lazy var activeTasks = Set<URLSessionTask>()
    
    //MARK: Singleton
    
    static let shared = APIClient()
    
    //MARK: Initialization
    
    private override init() {
        super.init()
    }
    
    //MARK: Public methods
    
    public func upload(_ urlRequest: URLRequest,_ data: Data) -> URLSessionTask {
        
        let task = session.uploadTask(with: urlRequest, from: data)
        activeTasks.insert(task)
        task.resume()
        
        return task
    }
    
    public func cancel() {
        for task in activeTasks {
            task.cancel()
        }
    }
}

//MARK: - URLSessionDataDelegate

extension APIClient: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("APIClient: task \(dataTask.taskIdentifier) -> didReceiveData")
        
        // downcast for access to statusCode
        guard let httpResponse = dataTask.response as? HTTPURLResponse else { return }
       
        AutoUpload.shared.handler(data, httpResponse, dataTask)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("APIClient: task \(task.taskIdentifier) -> didCompleteWithError")
        
        if (activeTasks.remove(task) != nil) {
            print("APIClient: task \(task.taskIdentifier) -> removed from activeTasks.")
        } else {
            print("APIClient: task \(task.taskIdentifier) -> error removing from activeTasks.")
        }
        
        if let error = error {
            // client-side errors only ("unable to resolve the hostname or connect to the host")
            print("APIClient: task \(task.taskIdentifier) -> \(error.localizedDescription)")
        }
        
        // downcast for access to statusCode
        guard let httpResponse = task.response as? HTTPURLResponse else {
            return
        }
        
        print("APIClient: task \(task.taskIdentifier) -> STATUS \(httpResponse.statusCode)")
    }
    
}
