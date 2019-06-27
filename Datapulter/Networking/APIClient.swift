//
//  APIClient.swift
//  Datapulter
//
//  Created by Craig Rachel on 4/27/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import os.log

class APIClient: NSObject {
    
    //MARK: Properties
    
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpAdditionalHeaders = ["User-Agent": "Datapulter/\(Bundle.main.releaseVersionNumber ?? "")"]
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = false
        return URLSession(configuration: configuration,
                          delegate: self, delegateQueue: nil)
    }()
    
    private lazy var activeTasks = Set<URLSessionTask>()
    
    var clientErrors = 0

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
    
    public func uploadTask(with urlRequest: URLRequest,from data: Data,completionHandler: @escaping NetworkCompletionHandler) -> URLSessionTask {
        let task = session.uploadTask(with: urlRequest, from: data, completionHandler: completionHandler)
        
        activeTasks.insert(task)
        
        return task
    }
    
    public func uploadTask(with urlRequest: URLRequest,fromFile url: URL,completionHandler: @escaping NetworkCompletionHandler) -> URLSessionTask {
        let task = session.uploadTask(with: urlRequest, fromFile: url, completionHandler: completionHandler)
        
        activeTasks.insert(task)
        
        return task
    }
    
    public func dataTask(with urlRequest: URLRequest,completionHandler: @escaping NetworkCompletionHandler) -> URLSessionTask {
        let task = session.dataTask(with: urlRequest, completionHandler: completionHandler)
        
        activeTasks.insert(task)
        
        return task
    }
    
    public func isActive() -> Bool {
        return !activeTasks.isEmpty
    }
    
    public func cancel() {
        os_log("cancelling all tasks", log: .apiclient, type: .info)
        
        for task in activeTasks {
            task.cancel()
        }
        
        activeTasks.removeAll()
    }
    
    public func suspend() {
        os_log("suspending all tasks", log: .apiclient, type: .info)
        
        for task in activeTasks {
            task.suspend()
        }
    }
    
    public func resume() {
        os_log("resuming all tasks", log: .apiclient, type: .info)
        
        for task in activeTasks {
            task.resume()
        }
    }
    
    public func remove(_ task: URLSessionTask) {
        activeTasks.remove(task)
    }
}

//MARK: - URLSessionDataDelegate

extension APIClient: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // downcast for access to statusCode
        guard let httpResponse = dataTask.response as? HTTPURLResponse else { return }
       
        //print("\(dataTask.taskIdentifier) didReceivedata. calling handler")
        AutoUpload.shared.handler(data, httpResponse, dataTask)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        
        if (activeTasks.remove(task) == nil) {
            os_log("could not remove task %d from activeTasks", log: .apiclient, type: .error, task.taskIdentifier)
        }
        
        if let error = error {
            // client-side errors only ("unable to resolve the hostname or connect to the host")
            clientErrors += 1
            
            os_log("task %d %@", log: .apiclient, type: .error, task.taskIdentifier, error.localizedDescription)
            
            AutoUpload.shared.clientError(task)
        }
        
        // downcast for access to statusCode
        guard let httpResponse = task.response as? HTTPURLResponse else {
            return
        }
        
        if (httpResponse.statusCode != 200) {
            os_log("task %d status %d", log: .apiclient, type: .info, task.taskIdentifier, httpResponse.statusCode)
        }
        //print("\(task.taskIdentifier) didcompletwitherror. calling handler")
        AutoUpload.shared.handler(nil, httpResponse, task)
    }
    
}
