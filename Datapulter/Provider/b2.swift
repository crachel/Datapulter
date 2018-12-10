//
//  b2.swift
//
//
//  Created by Craig Rachel on 12/5/18.
//

import UIKit

class b2: Provider {
    
    //MARK: Properties

    var Account: String
    var Key: String
    var Bucket: String
    var Versions: Bool
    var HardDelete: Bool
    var UploadCutoff: Int
    var ChunkSize: Int
    
    struct const {
        static let defaultEndpoint = "https://api.backblazeb2.com"
        static let headerPrefix = "x-bz-info-"
        static let timeKey = "src_last_modified_millis"
        static let timeHeader = headerPrefix + timeKey
        static let sha1Key = "large_file_sha1"
        static let sha1Header = "X-Bz-Content-Sha1"
        static let sha1InfoHeader = headerPrefix + sha1Key
        static let testModeHeader = "X-Bz-Test-Mode"
        static let retryAfterHeader = "Retry-After"
        static let maxParts = 10000
        static let maxVersions = 100 // maximum number of versions we search in --b2-versions mode
        static let minChunkSize = 5 * 1024 * 1024
        static let defaultChunkSize = 96 * 1024 * 1024
        static let defaultUploadCutoff = 200 * 1024 * 1024
    }
    
    // Remote describes a b2 remote
    struct Remote {
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
    }
    
    // Object describes a b2 object
    struct Object {
        //fs       *Fs          // what this object is part of
        var remote: String      // The remote path
        var id: String          // b2 id of the file
        var modTime: Date       // The modified time of the object if known
        var sha1: String        // SHA-1 hash if known
        var size: Int64         // Size of the object
        var mimeType: String    // Content-Type of the object
    }
    
    //MARK: Types
    
    struct PropertyKey {
        static let name = "name"
    }
    
    //MARK: Initialization
    init(name: String, Account: String, Key: String, Bucket: String, Versions: Bool, HardDelete: Bool, UploadCutoff: Int, ChunkSize: Int) {
        self.Account = Account
        self.Key = Key
        self.Bucket = Bucket
        self.Versions = Versions
        self.HardDelete = HardDelete
        self.UploadCutoff = UploadCutoff
        self.ChunkSize = ChunkSize
        super.init(name: name, backend: .Backblaze)
    }
    
    //MARK: NSCoding
    
    required convenience init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
