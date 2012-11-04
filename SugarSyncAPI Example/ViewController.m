//
//  ViewController.m
//  SugarSyncAPI Example
//
//  Created by Yaniv Kalsky on 05/11/12.
//  Copyright (c) 2012 Yaniv Kalsky. All rights reserved.
//

#import "ViewController.h"
#import "SugarSyncAPI.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    //login
    [[SugarSyncAPI sharedAPI] SSConnectWithUser:@"user" andPassword:@"pass"];
    
    //upload
    [[SugarSyncAPI sharedAPI] SSUploadFile:@"aaa.zip" fromPath:@"documents path" toFolder:@"App Backup"];
    
    //download
    [[SugarSyncAPI sharedAPI] SSDownloadFile:@"aaa.zip" fromFolder:@"App Backup" intoPath:@"documents path"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
