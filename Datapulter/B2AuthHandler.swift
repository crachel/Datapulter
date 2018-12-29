//
//  B2AuthHandler.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/18/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Alamofire

class B2AuthHandler: RequestAdapter, RequestRetrier {
    
    private typealias RefreshCompletion = (_ succeeded: Bool, _ authorizationToken: String?) -> Void
    
    private let sessionManager: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.httpHeaders = HTTPHeaders.default

        return URLSession(configuration: configuration)
    }()
    
    private let lock = NSLock()
    
    private var account: String
    private var baseURLString: String
    private var key: String
    private var authorizationToken: String
    
    private var isRefreshing = false
    private var requestsToRetry: [RequestRetryCompletion] = []
    
    // MARK: - Initialization
    
    public init(account: String, baseURLString: String, key: String, authorizationToken: String) {
        self.account = account
        self.baseURLString = baseURLString
        self.key = key
        self.authorizationToken = authorizationToken
    }
    
    // MARK: - RequestAdapter
    
    func adapt(_ urlRequest: URLRequest, completion: @escaping (Result<URLRequest>) -> Void) {
        var urlRequest = urlRequest
        urlRequest.setValue(authorizationToken, forHTTPHeaderField: "Authorization")
        
        _ = Result(value: {
            return urlRequest
        })
        
    }
    
    // MARK: - RequestRetrier
    
    func should(_ manager: Session, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        
    }
    
}

