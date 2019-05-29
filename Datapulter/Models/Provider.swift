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
        let percentDone = CGFloat((totalAssetsUploaded * 100) / totalAssetsToUpload)
        
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
    
    public func fetch(from urlRequest: URLRequest, with uploadData: Data? = nil, from uploadURL: URL? = nil) -> Promise<(Data?, URLResponse?)> {
        /**
         Starts a URLSessionUploadTask or URLSessionDataTask depending on the
         HTTP method of the URLRequest.
         
         In addition to all client-side errors, it also treats any URLResponse
         status code other than 200 as a "validResponse" error so that we may
         parse the data (xml/json/etc) at the subclass and recover from it.
         */
        return Promise { fulfill, reject in
            
            var task = URLSessionTask()
            
            let completionHandler: NetworkCompletionHandler = { data, response, error in
                DispatchQueue.main.async {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
                
                APIClient.shared.remove(task)
                
                if (error != nil) {
                    reject(providerError.connectionError)
                }
                
                if let response = response as? HTTPURLResponse,
                    //let mimeType = response.mimeType,
                    //mimeType == HTTPHeaders.mimeType,
                    let data = data {
                    
                    if (response.statusCode == 200) {
                        fulfill((data, response))
                    } else if (400...503).contains(response.statusCode) {
                        print("validresponse")
                        reject(providerError.validResponse(data))
                        /*
                         do {
                         let jsonerror = try JSONDecoder().decode(JSONError.self, from: data)
                         reject (B2Error(rawValue: jsonerror.code) ?? providerError.unmatched)
                         } catch {
                         reject (providerError.invalidJson) // handled status code but unknown problem decoding JSON
                         }*/
                    } else {
                        print("unhandledstatuscode")
                        reject (providerError.unhandledStatusCode)
                    }
                } else {
                    print("invalidresponse")
                    reject (providerError.invalidResponse)
                }
            }
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            if (urlRequest.httpMethod == HTTPMethod.post) {
                if let data = uploadData {
                    task = APIClient.shared.uploadTask(with: urlRequest, from:data, completionHandler: completionHandler)
                    task.resume()
                } else if let url = uploadURL {
                    task = APIClient.shared.uploadTask(with: urlRequest, fromFile:url, completionHandler: completionHandler)
                    task.resume()
                } else {
                    task = APIClient.shared.dataTask(with: urlRequest, completionHandler: completionHandler)
                    task.resume()
                }
            } else if (urlRequest.httpMethod == HTTPMethod.get) {
                task = APIClient.shared.dataTask(with: urlRequest, completionHandler: completionHandler)
                task.resume()
            }
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

enum providerError: Error {
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
