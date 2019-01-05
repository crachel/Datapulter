//
//  B2AuthHandler.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/18/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

/*
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
        lock.lock() ; defer { lock.unlock() }
        
        if let response = request.task?.response as? HTTPURLResponse, response.statusCode == 401 {
            requestsToRetry.append(completion)
            
            if !isRefreshing {
                refreshTokens { [weak self] succeeded, uploadAuthorizationToken in
                    guard let strongSelf = self else { return }
                    
                    strongSelf.lock.lock() ; defer { strongSelf.lock.unlock() }
                    
                    if let uploadAuthorizationToken = uploadAuthorizationToken {
                        strongSelf.uploadAuthorizationToken = uploadAuthorizationToken
                    }
                    
                    strongSelf.requestsToRetry.forEach { $0(succeeded, 0.0) }
                    strongSelf.requestsToRetry.removeAll()
                }
            }
        } else {
            completion(false, 0.0)
        }
    }
    
    // MARK: - Private - Refresh Tokens
    
    private func refreshTokens(completion: @escaping RefreshCompletion) {
        guard !isRefreshing else { return }
        
        isRefreshing = true
        
        firstly {
            try! request(urlrequest: B2.Router.authorize_account(self.account, self.key).asURLRequest())
            }.then { json -> Promise<[String: Any]> in
                self.authorizationToken = json["authorizationToken"] as? String
                return try! self.request(urlrequest: B2.Router.list_buckets(json["apiUrl"] as! String, json["accountId"] as! String, json["authorizationToken"] as! String, self.bucketName).asURLRequest())
            }.then { json -> Promise<[String: Any]> in
                return try! self.request(urlrequest: B2.Router.get_upload_url(apiUrl: json["apiUrl"] as! String, accountAuthorizationToken: self.authorizationToken!, bucketId: json["bucketId"] as! String).asURLRequest())
            }.done { json in
                completion(true, json["authorizationToken"] as? String)
            }.catch { error in
                completion(false, nil)
            }.finally {
                self.isRefreshing = false
        }
    }
    
    // MARK: - Private - PromiseKit request
    
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
                    print(json)
                    seal.fulfill(json)
                case .failure(let error):
                    // Pass the error into the reject function, so we can check what causes the error
                    seal.reject(error)
                }
            }
        }
    }
}*/
