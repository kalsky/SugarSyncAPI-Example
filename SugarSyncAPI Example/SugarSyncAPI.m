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
@property (nonatomic,retain) NSString * userAgent;
@property (nonatomic,retain) NSMutableDictionary * fDictionary;

@end

@implementation SugarSyncAPI

@synthesize token;
@synthesize userAgent;
@synthesize fDictionary;

#define consumerKey @"SSSSSSSSSSSSSSSSSSSSSSSSS"
#define consumerSecret @"YYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYYY"

static SugarSyncAPI* _sharedAPI = nil;

#pragma mark Singleton Methods

+ (SugarSyncAPI*)sharedAPI
{
	if(!_sharedAPI) {
		static dispatch_once_t oncePredicate;
		dispatch_once(&oncePredicate, ^{
			_sharedAPI = [[self alloc] init];
            _sharedAPI.userAgent = [NSString stringWithFormat:@"%@/%@",
                                    [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"],
                                    [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]];
            
            if ([[NSUserDefaults standardUserDefaults] objectForKey:@"SSFDictionary"]==nil)
            {
                _sharedAPI.fDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
            }
            else
            {
                NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"SSFDictionary"];
                _sharedAPI.fDictionary = [NSMutableDictionary dictionaryWithDictionary:[NSKeyedUnarchiver unarchiveObjectWithData:data]];
            }
            
        });
    }
    return _sharedAPI;
}

#pragma mark - SugarSync API (private)
-(NSString*)GetBriefcaseFolder
{
    if ([self.fDictionary objectForKey:@"magicBriefcase"]==nil)
    {
        NSURL *url = [NSURL URLWithString:@"https://api.sugarsync.com/user"];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"GET"];
        [request addValue:self.token forHTTPHeaderField:@"Authorization"];
        [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
        
        NSHTTPURLResponse *response = NULL;
        NSError *requestError = NULL;
        
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
        NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
        
        NSRange range = [responseString rangeOfString:@"<magicBriefcase>"];
        
        NSString *syncfolders = [responseString substringWithRange:NSMakeRange(range.location+16, [responseString length]-(range.location+16))];
        
        range = [syncfolders rangeOfString:@"</magicBriefcase>"];
        syncfolders = [syncfolders substringWithRange:NSMakeRange(0, range.location)];
        
        [self.fDictionary setObject:syncfolders forKey:@"magicBriefcase"];
    }
    
    return [self.fDictionary objectForKey:@"magicBriefcase"];
}

-(NSString*)GetFolder:(NSString*)folderName
{
    YNSLog(@"GetFolder: %@",folderName);
    if ([self.fDictionary objectForKey:folderName]!=nil)
    {
        return (NSString*)[self.fDictionary objectForKey:folderName];
    }
    
    //get info of magic folder
    NSURL *url = [NSURL URLWithString:[self GetBriefcaseFolder]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    
    NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    NSString *responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    
    //get the subfolders link from the response (collections)
    NSRange range = [responseString rangeOfString:@"<collections>"];
    
    NSString *collections = [responseString substringWithRange:NSMakeRange(range.location+13, [responseString length]-(range.location+13))];
    
    
    range = [collections rangeOfString:@"</collections>"];
    collections = [collections substringWithRange:NSMakeRange(0, range.location)];
    //YNSLog(@"magicBriefcase collections: %@",collections);
    
    //get the list of subfolders
    url = [NSURL URLWithString:collections];
    request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    
    response = NULL;
    requestError = NULL;
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    responseString = [[[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding] autorelease];
    //YNSLog(@"GetFolder list of subfolders response:%@",responseString);
    
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
        [self.fDictionary setObject:ref forKey:folderName];
    }
    
    return ref;
    
}

-(NSString*)CreateFolder:(NSString*)folderName
{
    YNSLog(@"CreateFolder: %@",folderName);
    if ([self.fDictionary objectForKey:folderName]!=nil)
    {
        return (NSString*)[self.fDictionary objectForKey:folderName];
    }
    
    NSURL *url = [NSURL URLWithString:[self GetBriefcaseFolder]];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    
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

-(NSString*)GetFilePath:(NSString*)fileName fromPath:(NSString*)folderPath
{
    YNSLog(@"GetFilePath: %@",fileName);
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
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    
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
    YNSLog(@"SSConnectWithUser: %@", user);
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
    YNSLog(@"SSUploadFile: %@", fileName);
    NSURL *url;
    NSMutableURLRequest *request;
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    NSString * SSFilePath = nil;
    BOOL retVal = YES;
    
    NSString * fileKey = [NSString stringWithFormat:@"%@/%@",folderName,fileName];
    if ([self.fDictionary objectForKey:fileKey]!=nil)
    {
        SSFilePath = (NSString*)[self.fDictionary objectForKey:fileKey];
    }
    
    if (SSFilePath==nil)
    {
        NSString * folderPath = [self GetFolder:folderName];
        if (folderPath==nil)
        {
            //create folder
            folderPath = [self CreateFolder:folderName];
        }
        else
        {
            //try to get the file link
            SSFilePath = [self GetFilePath:fileName fromPath:folderPath];
        }
        
        if (SSFilePath==nil)
        {
            //create file
            url = [NSURL URLWithString:folderPath];
            request = [NSMutableURLRequest requestWithURL:url];
            [request setHTTPMethod:@"POST"];
            [request addValue:self.token forHTTPHeaderField:@"Authorization"];
            [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
            
            NSString * str = [NSString stringWithFormat:@"<file><displayName>%@</displayName><mediaType>application/octet-stream</mediaType></file>", fileName];
            
            [request setValue:@"application/xml; charset=utf-8" forHTTPHeaderField:@"Content-Type"];
            [request setHTTPBody:[str dataUsingEncoding:NSUTF8StringEncoding]];
            
            response = NULL;
            requestError = NULL;
            
            [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
            YNSLog(@"response code: %d",[response statusCode]);
            
            if ([response statusCode]<300 && [response respondsToSelector:@selector(allHeaderFields)]) {
                NSDictionary *dictionary = [response allHeaderFields];
                SSFilePath = [dictionary objectForKey:@"Location"];
            }
            else
            {
                YNSLog(@"error: %@", [requestError description]);
                retVal = NO;
            }
        }
    }
    
    //upload file
    if (SSFilePath!=nil)
    {
        url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/data",SSFilePath]];
        
        request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"PUT"];
        [request addValue:self.token forHTTPHeaderField:@"Authorization"];
        [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
        
        NSData *fileData = [NSData dataWithContentsOfFile:filePath];
        [request setHTTPBody:fileData];
        
        [request addValue:[NSString stringWithFormat:@"%d",[fileData length]] forHTTPHeaderField:@"Content-Length"];
        
        requestError = NULL;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
        YNSLog(@"response code: %d",[response statusCode]);
        
        if ([response statusCode]>=300 || requestError!=NULL)
        {
            if ([response statusCode]==404)
            {
                //try again without the cached file path
                _sharedAPI.fDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
                return [self SSUploadFile:fileName fromPath:filePath toFolder:folderName];
            }
            else
            {
                YNSLog(@"error: %@", [requestError description]);
                retVal = NO;
            }
        }
    }
    
    if (retVal==YES)
    {
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [self.fDictionary setObject:SSFilePath forKey:fileKey];
        [defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:self.fDictionary] forKey:@"SSFDictionary"];
    }
    return retVal;
}

-(BOOL)SSDownloadFile:(NSString*)fileName fromFolder:(NSString*)folderName intoPath:(NSString*)savePath
{
    YNSLog(@"SSDownloadFile: %@", fileName);
    NSURL *url;
    NSMutableURLRequest *request;
    NSHTTPURLResponse *response = NULL;
    NSError *requestError = NULL;
    NSData *responseData;
    NSString * SSFilePath = nil;
    
    NSString * fileKey = [NSString stringWithFormat:@"%@/%@",folderName,fileName];
    if ([self.fDictionary objectForKey:fileKey]!=nil)
    {
        SSFilePath = (NSString*)[self.fDictionary objectForKey:fileKey];
    }
    else
    {
        NSString * folderPath = [self GetFolder:folderName];
        if (folderPath==nil)
        {
            //folder does not exist
            return NO;
        }
        
        SSFilePath = [self GetFilePath:fileName fromPath:folderPath];
        
        if (SSFilePath==nil)
        {
            return NO;
        }
    }
    
    //get info of backup folder
    url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/data",SSFilePath]];
    request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"GET"];
    [request addValue:self.token forHTTPHeaderField:@"Authorization"];
    [request setValue:self.userAgent forHTTPHeaderField:@"User-Agent"];
    
    response = NULL;
    requestError = NULL;
    
    responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&requestError];
    YNSLog(@"SSDownloadFile responseData size:%d",[responseData length]);
    YNSLog(@"response code: %d",[response statusCode]);
    
    if ([response statusCode]<300 && [responseData length]>0)
    {
        //save the file
        return [responseData writeToFile:savePath atomically:YES];
    }
    else if ([response statusCode]==404)
    {
        //try again without the cached file path
        _sharedAPI.fDictionary = [NSMutableDictionary dictionaryWithCapacity:3];
        return [self SSDownloadFile:fileName fromFolder:folderName intoPath:savePath];
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
