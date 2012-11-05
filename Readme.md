This is a small class that allows uploading and downloading a file from SugarSync in iOS.
This is also the first time I share on github - so forgive me for rookie mistakes..

## Getting Started
in SugarSync.m, update both consumerKey and consumerSecret to get access to SugarSync.

Then just call these functions:

* To login:   [[SugarSyncAPI sharedAPI] SSConnectWithUser:@"user" andPassword:@"pass"];

* To upload a file:   [[SugarSyncAPI sharedAPI] SSUploadFile:@"aaa.zip" fromPath:@"documents path" toFolder:@"App Backup"];

* To download a file:   [[SugarSyncAPI sharedAPI] SSDownloadFile:@"aaa.zip" fromFolder:@"App Backup" intoPath:@"documents path"];


The files are uploaded to the MagicBriefcase folder under a sub folder that will get created.