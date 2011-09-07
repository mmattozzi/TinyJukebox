//
//  FSAudioScanner.h
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/23/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>

@class JukeboxConfig;

@interface FSAudioScanner : NSObject {
}

+ (BOOL) hasAudioExtension:(NSString *)file;
+ (void) rescan:(JukeboxConfig *)jukeboxConfig;
+ (void) alertClients;

@end
