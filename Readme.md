This is a small class that allows uploading and downloading a file from SugarSync in iOS.

Usage:
in SugarSync.m, update both consumerKey and consumerSecret
#define consumerKey @"SSSSSSSSSSSSSSSSSSSSSSSSS"
#define consumerSecret @"YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"

Then just call these functions:
//login
[[SugarSyncAPI sharedAPI] SSConnectWithUser:@"user" andPassword:@"pass"];

//upload
[[SugarSyncAPI sharedAPI] SSUploadFile:@"aaa.zip" fromPath:@"documents path" toFolder:@"App Backup"];

//download
[[SugarSyncAPI sharedAPI] SSDownloadFile:@"aaa.zip" fromFolder:@"App Backup" intoPath:@"documents path"];


The files are uploaded to the MagicBriefcase folder under a sub folder that will get created.