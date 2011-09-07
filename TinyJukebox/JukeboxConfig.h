//
//  JukeboxConfig.h
//  SimpleJukebox
//
//  Created by Michael Mattozzi on 6/12/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JukeboxConfig : NSObject {
    NSString *localLibraryDirectory;
    int port;
    BOOL allowRemoteControl;
    BOOL shareFiles;
    NSString *hostname;
}

@property (assign) NSString *localLibraryDirectory;
@property int port;
@property BOOL allowRemoteControl;
@property BOOL shareFiles;
@property (assign) NSString *hostname;

- (id)init;
- (id) initWithDirectory:(NSString *)directory port:(int)serverPort allowRemoteControl:(bool)allowControl shareFiles:(BOOL)share hostname:(NSString *)name;

@end
