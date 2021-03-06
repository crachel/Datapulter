//
//  Provider.swift
//  Datapulter
//
//  Created by Craig Rachel on 12/5/18.
//  Copyright © 2018 Craig Rachel. All rights reserved.
//

import UIKit
import Photos
import Promises

protocol Provider: AnyObject, Codable, AutoUploading {
    
    var metatype: ProviderMetatype { get }
    
    var name: String { get set }
    var remoteFileList: [String: Data] { get set }
    
    var cell: ProviderTableViewCell? { get set }
    
    var uploadingAssets: [URLSessionTask: PHAsset] { get set }
    var assetsToUpload: Set<PHAsset> { get set }
    var totalAssetsToUpload: Int { get set }
    var totalAssetsUploaded: Int { get set }
    
    func authorize() -> Promise<Bool>
    func decodeURLResponse(_ response: HTTPURLResponse,_ data: Data?,_ task: URLSessionTask,_ asset: PHAsset)
    func getUploadFileURLRequest(from asset: PHAsset) -> Promise<(URLRequest?, Data?)>
    func willDelete()
    func check()
}

extension Provider {
    public func updateRing() {
        
        var percentDone: CGFloat
        
        if (totalAssetsToUpload > 0) {
            percentDone = CGFloat((totalAssetsUploaded * 100) / totalAssetsToUpload)
        } else {
            return
        }
        
        DispatchQueue.main.async {
            self.cell?.ringView.startProgress(to: percentDone, duration: 0) {
                if (self.totalAssetsUploaded == self.totalAssetsToUpload) {
                    self.cell?.ringView.innerRingColor = .green
                    
                    self.hud("Done uploading!")
                    
                    self.totalAssetsToUpload = 0
                } else {
                    self.hud("\(self.totalAssetsUploaded) of \(self.totalAssetsToUpload)")
                }
            }
        }
    }
    
    public func hud(_ display: String) {
        DispatchQueue.main.async {
            self.cell?.hudLabel.text = display
        }
    }
    
    public func fetch(with urlRequest: URLRequest, from uploadData: Data? = nil, fromFile uploadURL: URL? = nil) -> Promise<(Data?, URLResponse?)> {
        return Promise { fulfill, reject in
            
            var task = URLSessionTask()
            
            let completionHandler: NetworkCompletionHandler = { data, response, error in
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                APIClient.shared.remove(task)
                
                if (error != nil) {
                    reject(ProviderError.connectionError)
                }
                
                if let response = response as? HTTPURLResponse,
                    let data = data {
                    
                    if (response.statusCode == 200) {
                        fulfill((data, response))
                    } else if (400...503).contains(response.statusCode) {
                        reject(ProviderError.validResponse(data))
                    } else {
                        reject(ProviderError.unhandledStatusCode)
                    }
                } else {
                    reject(ProviderError.invalidResponse)
                }
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            if let data = uploadData {
                task = APIClient.shared.uploadTask(with: urlRequest, from:data, completionHandler: completionHandler)
            } else if let url = uploadURL {
                task = APIClient.shared.uploadTask(with: urlRequest, fromFile:url, completionHandler: completionHandler)
            } else {
                task = APIClient.shared.dataTask(with: urlRequest, completionHandler: completionHandler)
            }
            
            task.resume()
        }
    }
}

enum ProviderMetatype: String, Meta {
    
    typealias Element = Provider
    
    case b2
    case s3
    
    static func metatype(for element: Provider) -> ProviderMetatype {
        return element.metatype
    }
    
    var type: Decodable.Type {
        switch self {
        case .b2: return B2.self
        case .s3: return S3.self
        }
    }
}

enum ProviderError: Error {
    case optionalBinding
    case connectionError
    case invalidResponse
    case invalidJson
    case preparationFailed
    case unhandledStatusCode
    case foundNil
    case largeFile
    case unmatched
    case validResponse(Data)
    var localizedDescription: String {
        switch self {
        case .optionalBinding: return "Optional binding"
        case .connectionError: return "Client side error"
        case .invalidResponse: return "Invalid response"
        case .invalidJson: return "Could not decode JSON"
        case .preparationFailed: return "Preparation failed"
        case .unhandledStatusCode: return "Status code not handled"
        case .foundNil: return "Found nil"
        case .largeFile: return "Large file encountered"
        case .unmatched: return "Unmatched error"
        case .validResponse: return "Response is valid"
        }
    }
}
