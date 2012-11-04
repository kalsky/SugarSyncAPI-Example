//
//  SugarSyncAPI.h
//  QuickReminders
//
//  Created by Yaniv Kalsky on 02/11/12.
//
//

#import <Foundation/Foundation.h>

@interface SugarSyncAPI : NSObject

+ (SugarSyncAPI*)sharedAPI;

-(BOOL)SSConnectWithUser:(NSString*)user andPassword:(NSString*)password;
-(BOOL)SSCreateFolder:(NSString*)folderName;
-(BOOL)SSUploadFile:(NSString*)fileName fromPath:(NSString*)filePath toFolder:(NSString*)folderPath;
-(BOOL)SSDownloadFile:(NSString*)fileName fromFolder:(NSString*)folderName intoPath:(NSString*)savePath;

@end
