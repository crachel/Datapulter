//
//  b2.swift
//
//
//  Created by Craig Rachel on 12/5/18.
//

import UIKit

class b2: Provider {
    
    //MARK: Properties
    
    var root: String                       // the path we are working on if any
    //opt           Options                      // parsed config options
    //features      *fs.Features                 // optional features
    //srv           *rest.Client                 // the connection to the b2 server
    //var bucket: String                       // the bucket we are working on
    //bucketOKMu    sync.Mutex                   // mutex to protect bucket OK
    //bucketOK      bool                         // true if we have created the bucket
    //bucketIDMutex sync.Mutex                   // mutex to protect _bucketID
    //var _bucketID: String                       // the ID of the bucket we are working on
    //info          api.AuthorizeAccountResponse // result of authorize call
    //uploadMu      sync.Mutex                   // lock for upload variable
    //uploads       []*api.GetUploadURLResponse  // result of get upload URL calls
    //authMu        sync.Mutex                   // lock for authorizing the account
    //pacer         *pacer.Pacer                 // To pace and retry the API calls
    //bufferTokens  chan []byte                  // control concurrency of multipart uploads
    
    struct Options {
        var Account: String
        var Key: String
        var Endpoint: String
        var Versions: Bool
        var HardDelete: Bool
        var UploadCutoff: Int64
        var ChunkSize: Int64
    }
    
    // Object describes a b2 object
    struct Object {
        //fs       *Fs          // what this object is part of
        var remote: String      // The remote path
        var id: String          // b2 id of the file
        //modTime  time.Time    // The modified time of the object if known
        var sha1: String        // SHA-1 hash if known
        var size: Int64         // Size of the object
        var mimeType: String    // Content-Type of the object
    }
    
    //MARK: Types
    
    struct PropertyKey {
        static let name = "name"
    }
    
    //MARK: Initialization
    init(root: String) {
        self.root = root
        super.init(name: "b2")
    }
    
    //MARK: NSCoding
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
