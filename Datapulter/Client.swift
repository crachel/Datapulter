//
//  Client.swift
//  Datapulter
//
//  Created by Craig Rachel on 1/3/19.
//  Copyright © 2019 Craig Rachel. All rights reserved.
//

import UIKit
import Alamofire
import PromiseKit

class Client {
    
    //MARK: Properties
    static let shared = Client()
    
    var sessionB2: Alamofire.Session
    //var session: URLSession
    
    //MARK: Initialization
    
    private init() {
        
        let configurationB2 = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.B2.background")
        configurationB2.allowsCellularAccess = false
        sessionB2 = Alamofire.Session(configuration: configurationB2)
        //let configuration = URLSessionConfiguration.background(withIdentifier: "com.example.Datapulter.background")
        //configuration.allowsCellularAccess = false
        //session = URLSession(configuration: configuration)
    }
    
    //MARK: Public Methods
    
    
    public func requestB2(urlrequest: URLRequest) -> Promise<Data> {
        return Promise { seal in
            sessionB2.request(urlrequest).responseData { (response) in
                switch response.result {
                case .success(let data):
                    // Pass the data into the fulfill function, so we can receive the value
                    seal.fulfill(data)
                case .failure(let error):
                    // Pass the error into the reject function, so we can check what causes the error
                    seal.reject(error)
                }
            }
        }
    }
    /*
    public func requestB2(urlrequest: URLRequest) -> Promise<[String: Any]> {
        return Promise { seal in
            sessionB2.request(urlrequest).responseJSON { (response) in
                switch response.result {
                case .success(let json):
                    // If there is not JSON data, cause an error (`reject` function)
                    guard let json = json as? [String: Any] else {
                        return seal.reject(AFError.responseValidationFailed(reason: .dataFileNil))
                    }
                    // Pass the JSON data into the fulfill function, so we can receive the value
                    seal.fulfill(json)
                case .failure(let error):
                    // Pass the error into the reject function, so we can check what causes the error
                    seal.reject(error)
                }
            }
        }
    }*/
    
}
