//
//  SugarSyncAPI.m
//  QuickReminders
//
//  Created by Yaniv Kalsky on 02/11/12.
//
//

#import "SugarSyncAPI.h"

@interface SugarSyncAPI()

@property (nonatomic,retain) NSString * token;
@property (nonatomic,retain) NSString * rootFolder;
@property (nonatomic,retain) NSMutableDictionary * foldersDictionary;

@end

@implementation SugarSyncAPI

@synthesize token;
@synthesize rootFolder;
@synthesize foldersDictionary;

#define consumerKey @"SSSSSSSSSSSSSSSSSSSSSSSSS"
#define consumerSecret @"YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"

static SugarSyncAPI* _sharedAPI;

#pragma mark Singleton Methods

+ (SugarSyncAPI*)sharedAPI
{
	if(!_sharedAPI) {
		static dispatch_once_t oncePredicate;
		dispatch_once(&oncePredicate, ^{
			_sharedAPI = [[self alloc] init];
        });
    }
    return _sharedAPI;
}

#pragma mark - SugarSync API (private)
-(NSString*)GetRootFolder
{
    if (self.rootFolder==nil)
    {
        NSURL *url = [NSURL URLWithString:@"https://api.sugarsync.com/user"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request addValue:self.token forHTTPHeaderField:@"Authorization"];
        
        NSHTTPURLResponse *response = NULL;
        NSError *requestError = NULL;
        
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
        NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
        YNSLog(@"GetRootFolder response:%@",responseString);
        
        NSRange range = [responseString rangeOfString:@"<magicBriefcase>"];
        
        NSString *syncfolders = [responseString substringWithRange:NSMakeRange(range.location+16, [responseString length]-(range.location+16))];
        YNSLog(@"syncfolders: %@",syncfolders);
        
        range = [syncfolders rangeOfString:@"</magicBriefcase>"];
        syncfolders = [syncfolders substringWithRange:NSMakeRange(0, range.location)];
        YNSLog(@"magicBriefcase: %@",syncfolders);
        
        self.rootFolder = syncfolders;
    }
    
    return self.rootFolder;
}

-(NSString*)GetFolder:(NSString*)folderName
{
    if (self.foldersDictionary==nil)
    {
        self.foldersDictionary = [[NSMutableDictionary alloc] init];
    }
    else if ([self.foldersDictionary objectForKey:folderName]!=nil)
    {
        return (NSString*)[self.foldersDictionary objectForKey:folderName];
    }
    
    //get info of magic folder
    NSURL *url = [NSURL URLWithString:[self GetRootFolder]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    
    //get the subfolders link from the response (collections)
    NSRange range = [responseString rangeOfString:@"<collections>"];
    
    NSString *collections = [responseString substringWithRange:NSMakeRange(range.location+13, [responseString length]-(range.location+13))];
    
    
    range = [collections rangeOfString:@"</collections>"];
    collections = [collections substringWithRange:NSMakeRange(0, range.location)];
    YNSLog(@"magicBriefcase collections: %@",collections);
    
    //get the list of subfolders
    url = [NSURL URLWithString:collections];
    request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:token forHTTPHeaderField:@"Authorization"];
    
    response = NULL;
    requestError = NULL;
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    YNSLog(@"GetFolder list of subfolders response:%@",responseString);
    
    //get the subfolder link from the response (ref)
    range = [responseString rangeOfString:[NSString stringWithFormat:@"<displayName>%@</displayName>",folderName]];
    NSString * ref = nil;
    if (range.length>0)
    {
        ref = [responseString substringFromIndex:range.location];
        
        range = [ref rangeOfString:@"<ref>"];
        ref = [ref substringFromIndex:range.location+5];
        
        range = [ref rangeOfString:@"</ref>"];
        ref = [ref substringToIndex:range.location];
    }
    
    if (ref!=nil)
    {
        [self.foldersDictionary setObject:ref forKey:folderName];
    }
    
    return ref;
    
}

-(NSString*)CreateFolder:(NSString*)folderName
{
    if (self.foldersDictionary!=nil && [self.foldersDictionary objectForKey:folderName]!=nil)
    {
        return (NSString*)[self.foldersDictionary objectForKey:folderName];
    }
    
    NSURL *url = [NSURL URLWithString:[self GetRootFolder]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    
    NSString * str = [NSString stringWithFormat:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?><folder><displayName>%@</displayName></folder>", folderName];
    
    [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[str dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    
    if ([response respondsToSelector:@selector(allHeaderFields)])
    {
        NSDictionary *dictionary = [response allHeaderFields];
        YNSLog(@"CreateFolder response headers: %@",[dictionary description]);
        return [dictionary objectForKey:@"Location"];
    }
    else
    {
        return nil;
    }
}

-(NSString*)GetFile:(NSString*)fileName fromPath:(NSString*)folderPath
{
    NSURL *url;
    NSMutableURLRequest *request;
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    NSData *responseData;
    
    NSString * SSFilePath = nil;
    
    //get info of backup folder
    url = [NSURL URLWithString:folderPath];
    request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    
    response = NULL;
    requestError = NULL;
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    
    //get link to files in backup folder
    NSRange range = [responseString rangeOfString:@"<files>"];
    
    NSString *files = [responseString substringWithRange:NSMakeRange(range.location+7, [responseString length]-(range.location+7))];
    
    range = [files rangeOfString:@"</files>"];
    files = [files substringWithRange:NSMakeRange(0, range.location)];
    
    //get files inside backup folder
    url = [NSURL URLWithString:files];
    request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:token forHTTPHeaderField:@"Authorization"];
    
    response = NULL;
    requestError = NULL;
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    
    //get link to the file
    range = [responseString rangeOfString:[NSString stringWithFormat:@"<displayName>%@</displayName>",fileName]];
    NSString * ref = nil;
    if (range.length>0)
    {
        ref = [responseString substringFromIndex:range.location];
        
        range = [ref rangeOfString:@"<ref>"];
        ref = [ref substringFromIndex:range.location+5];
        
        range = [ref rangeOfString:@"</ref>"];
        ref = [ref substringToIndex:range.location];
        
        SSFilePath = ref;//get file path
    }
    
    return SSFilePath;
}

#pragma mark - SugarSync API (public)


-(BOOL)SSConnectWithUser:(NSString*)user andPassword:(NSString*)password
{
    NSURL *url = [NSURL URLWithString:@"https://api.sugarsync.com/authorization"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    NSString * str = [NSString stringWithFormat:@"<?xml version=\"1.0\"?>\n<authRequest><username>%@</username><password>%@</password><accessKeyId>%@</accessKeyId><privateAccessKey>%@</privateAccessKey></authRequest>", user,password,consumerKey,consumerSecret];
    
    [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[str dataUsingEncoding:NSUTF8StringEncoding]];
    
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    
    /*NSData *responseData = */
    [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    if ([response respondsToSelector:@selector(allHeaderFields)]) {
        NSDictionary *dictionary = [response allHeaderFields];
        self.token = [dictionary objectForKey:@"Location"];
        return YES;
    }
    else
    {
        self.token = nil;
        return NO;
    }
}

-(BOOL)SSCreateFolder:(NSString*)folderName
{
    NSString * folderPath = [self CreateFolder:folderName];
    
    return (folderPath!=nil);
}

-(BOOL)SSUploadFile:(NSString*)fileName fromPath:(NSString*)filePath toFolder:(NSString*)folderName
{
    NSURL *url;
    NSMutableURLRequest *request;
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    
    NSString * SSFilePath = nil;
    
    NSString * folderPath = [self GetFolder:folderName];
    if (folderPath==nil) 
    {
        //create folder
        folderPath = [self CreateFolder:folderName];
    }
    else
    {
        //try to get the file link
        SSFilePath = [self GetFile:fileName fromPath:folderPath];
    }
    
    if (SSFilePath==nil)
    {
        //create file
        url = [NSURL URLWithString:folderName];
        request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request addValue:self.token forHTTPHeaderField:@"Authorization"];
        
        NSString * str = [NSString stringWithFormat:@"<file><displayName>%@</displayName><mediaType>application/octet-stream</mediaType></file>", fileName];
        
        [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
        [request setHTTPBody:[str dataUsingEncoding:NSUTF8StringEncoding]];
        
        response = NULL;
        requestError = NULL;
        
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
        
        if ([response respondsToSelector:@selector(allHeaderFields)]) {
            NSDictionary *dictionary = [response allHeaderFields];
            SSFilePath = [dictionary objectForKey:@"Location"];
            YNSLog(@"response code: %d",[response statusCode]);
        }
        else if (requestError!=NULL)
        {
            YNSLog(@"error: %@", [requestError description]);
            return NO;
        }
    }
    
    //upload file
    if (SSFilePath)
    {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/data",SSFilePath]];
        
        request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"PUT"];
        [request addValue:self.token forHTTPHeaderField:@"Authorization"];
        
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        [request setHTTPBody:fileData];
        
        [request addValue:[NSString stringWithFormat:@"%d",[fileData length]] forHTTPHeaderField:@"Content-Length"];
        
        requestError = NULL;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
        
        if (requestError!=NULL)
        {
            YNSLog(@"error: %@", [requestError description]);
            return NO;
        }
    }
    
    return YES;
}

-(BOOL)SSDownloadFile:(NSString*)fileName fromFolder:(NSString*)folderName intoPath:(NSString*)savePath
{
    NSURL *url;
    NSMutableURLRequest *request;
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    NSData *responseData;
    
    NSString * folderPath = [self GetFolder:folderName];
    if (folderPath==nil)
    {
        //folder does not exist
        return NO;
    }
    
    NSString * filePath = [self GetFile:fileName fromPath:folderPath];
    
    if (filePath==nil)
    {
        return NO;
    }
    
    NSString * SSFilePath = [NSString stringWithFormat:@"%@/data",filePath];
    
    //get info of backup folder
    url = [NSURL URLWithString:SSFilePath];
    request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    
    response = NULL;
    requestError = NULL;
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    YNSLog(@"SSDownloadFile responseData size:%d",[responseData length]);
    if ([responseData length]>0)
    {
        //save the file
        return [responseData writeToFile:savePath atomically:YES];
    }
    else
    {
        if (requestError!=NULL)
        {
            YNSLog(@"error: %@", [requestError description]);
        }
        return NO;
    }
    
}

@end
