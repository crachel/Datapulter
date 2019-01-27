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
    
    static let maxActiveTasks = 5
    
    private var session: URLSession!
    private var activeTaskIds: Set<Int>?
    
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
    
    public func upload(_ urlrequest: URLRequest,_ url: URL) -> Int {
        
        let task = session.uploadTask(with: urlrequest, fromFile: url)
        activeTaskIds?.insert(task.taskIdentifier)
        task.resume()
        
        return (task.taskIdentifier)
        
    }
    
    public func test(_ urlrequest: URLRequest) {
       
        session.dataTask(with: urlrequest)
    }
    
    public func isActive() -> Bool {
        return ((activeTaskIds?.count) != nil)
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
        //print(totalBytesSent)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("urlSession -> didReceiveData")
        
        guard let httpResponse = dataTask.response as? HTTPURLResponse else { return }
        
        AutoUpload.shared.handler(data, httpResponse, dataTask.taskIdentifier)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        print("urlSession -> didCompleteWithError")
        
        guard let httpResponse = task.response as? HTTPURLResponse else { return }
        
        activeTaskIds?.remove(task.taskIdentifier)
        
        if let error = error {
            // handle failure here
            //
            
            print("\(error.localizedDescription)")
        } else {
            
            if (httpResponse.statusCode == 401) {
                
                print("urlSession -> STATUS 401")
                
                // prob unauthorized
                // get new url & token.
                // get image data somehow
                // AutoUpload.reauthorizeRequest(newRequest, data)
                /*
                 unlikely to see this since getuploadurl call should rectify 401 shortly before uploadfile call
 */
                
                //var newRequest = task.originalRequest
                //newRequest?.setValue("newgoodtoken", forHTTPHeaderField: "Authorization")
                //AutoUpload.reauthorize(newRequest)
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


