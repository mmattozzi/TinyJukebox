//
//  JukeboxConfig.m
//  SimpleJukebox
//
//  Created by Michael Mattozzi on 6/12/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "JukeboxConfig.h"

@implementation JukeboxConfig

@synthesize localLibraryDirectory;
@synthesize port;
@synthesize allowRemoteControl;
@synthesize shareFiles;
@synthesize hostname;

- (id)init {
    self = [super init];
    return self;
}

- (id) initWithDirectory:(NSString *)directory port:(int)serverPort allowRemoteControl:(bool)allowControl shareFiles:(BOOL)share hostname:(NSString *)name {
    self = [super init];
    if (self) {
        self.localLibraryDirectory = directory;
        self.port = serverPort;
        self.allowRemoteControl = allowControl;
        self.shareFiles = share;
        self.hostname = name;
    }
    
    return self;
}

@end
