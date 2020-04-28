# Datapulter
Beyond The Wall

App written in Swift for iOS. Uploads camera roll to object storage providers.

Clone the repo and open the workspace in Xcode then build for your iOS device

![alt text](https://raw.githubusercontent.com/crachel/Datapulter/master/screenshots.png)

Datapulter uploads your camera roll (photos, videos, slo-mo, etc) to object storage. Supported providers include:

* Backblaze B2
* Amazon Web Services (AWS) S3
* DigitalOcean Spaces
* Minio
* ...and any other S3-compliant provider!

MORE FEATURES
* Keeps the original file format & name as it exists on your device.
* File hashes are compared after transfer to ensure integrity.
* No ads.
* 100% written in Swift.

FAQ
Q: Why no background upload?
A: Apple's app sandbox does not allow it. This only works by moving the camera roll to temporary storage prior to upload.

Q: Does Datapulter check that source and destination match?
Not currently. Datapulter maintains a local file list but If you uninstall then reinstall you will need to do a full backup. Likewise if you alter the destination manually by adding or removing objects.

Q: What IAM permission do I need for S3?
A: ListAllMyBuckets is used for account authorization. The others used are: AbortMultipartUpload, GetObject, GetObjectAcl, ListMultipartUploadParts, PutObject, and PutObjectAcl.

Q: What is the "prefix" parameter?
A: Object storage has no concept of a directory. Most clients however will allow you to simulate a directory structure by adding a prefix to the filename.

Q: What is Virtual Hosting for S3 providers?
A: Some S3-compliant providers may support Virtual Hosting or Path-style syntax for forming endpoint URLs. Datapulter supports both.
