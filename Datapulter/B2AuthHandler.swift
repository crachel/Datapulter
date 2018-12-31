//
//  B2AuthHandler.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/18/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Alamofire
import PromiseKit

class B2AuthHandler: RequestAdapter, RequestRetrier {
    
    private typealias RefreshCompletion = (_ succeeded: Bool, _ uploadAuthorizationToken: String?) -> Void
    
    private let sessionManager: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.httpHeaders = HTTPHeaders.default

        return Alamofire.Session(configuration: configuration)
    }()
    
    private let lock = NSRecursiveLock()
    
    private var account: String
    private var baseURLString: String
    private var key: String
    private var authorizationToken: String?
    private var uploadAuthorizationToken: String?
    private var bucketName: String
    
    private var isRefreshing = false
    private var requestsToRetry: [RequestRetryCompletion] = []
    
    // MARK: - Initialization
    
    public init(account: String, baseURLString: String, key: String, bucketName: String) {
        self.account = account
        self.baseURLString = baseURLString
        self.key = key
        self.bucketName = bucketName
    }
    
    // MARK: - RequestAdapter
    
    func adapt(_ urlRequest: URLRequest, completion: @escaping (Alamofire.Result<URLRequest>) -> Void) {
        var urlRequest = urlRequest
        urlRequest.setValue(uploadAuthorizationToken, forHTTPHeaderField: "Authorization")
        
        _ = Alamofire.Result(value: {
            return urlRequest
        })
        
    }
    
    // MARK: - RequestRetrier
    
    func should(_ manager: Session, retry request: Request, with error: Error, completion: @escaping RequestRetryCompletion) {
        
    }
    
    // MARK: - Private - Refresh Tokens
    
    private func refreshTokens(completion: @escaping RefreshCompletion) {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        
        firstly {
            return try! request(urlrequest: B2.Router.authorize_account(accountId: self.account, applicationKey: self.key).asURLRequest())
        }.then { json -> Promise<[String: Any]> in
            self.authorizationToken = json["authorizationToken"] as? String
            return try! self.request(urlrequest: B2.Router.list_buckets(apiUrl: json["apiUrl"] as! String, accountId: json["accountId"] as! String, accountAuthorizationToken: json["authorizationToken"] as! String, bucketName: self.bucketName).asURLRequest())
        }.then { json -> Promise<[String: Any]> in
            return try! self.request(urlrequest: B2.Router.get_upload_url(apiUrl: json["apiUrl"] as! String, accountAuthorizationToken: self.authorizationToken!, bucketId: json["bucketId"] as! String).asURLRequest())
        }.done { json in
            completion(true, json["authorizationToken"] as? String)
        }.catch { error in
            completion(false, nil)
        }.finally {
            self.isRefreshing = false
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
        }
        
        /*
        sessionManager.request(try! B2.Router.authorize_account(accountId: self.account, applicationKey: self.key).asURLRequest()).responseJSON { [weak self] response in
            guard let strongSelf = self else { return }
            
            if
                let json = response.result.value as? [String: Any],
                let authorizationToken = json["authorizationToken"] as? String
            {
               
                completion(true, authorizationToken)                 
            } else {
                completion(false, nil)
            }
            
            strongSelf.isRefreshing = false
        }*/
    }
    
    private func request(urlrequest: URLRequest) -> Promise<[String: Any]> {
        return Promise { seal in
            sessionManager.request(urlrequest).responseJSON { (response) in
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
    }
}

/*
self!.sessionManager.request(try! B2.Router.list_buckets(apiUrl: json["apiUrl"] as! String, accountId: json["accountId"] as! String, accountAuthorizationToken: authorizationToken, bucketName: self!.bucketName).asURLRequest()).responseJSON { response in
    
}
 */
