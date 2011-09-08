//
//  FSAudioScanner.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/23/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "FSAudioScanner.h"
#import "AudioTag.h"
#import "JukeboxConfig.h"
#import "JukeboxData.h"
#import "TinyJukeboxAppDelegate.h"

@implementation FSAudioScanner

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

+ (BOOL) hasAudioExtension:(NSString *)file {
    return ( [file hasSuffix:@".mp3"] || [file hasSuffix:@".aac"] || [file hasSuffix:@".mp4"] || [file hasSuffix:@".m4a"] );
}

+ (void) rescan:(JukeboxConfig *)jukeboxConfig {
    [[TinyJukeboxAppDelegate singleton] setStatusToIndexing];
    BOOL isDir=NO;
    NSFileManager *fileManager = [[NSFileManager alloc] init];
    NSString *expandedPath = [jukeboxConfig.localLibraryDirectory stringByExpandingTildeInPath];
    BOOL dirExists = [fileManager fileExistsAtPath:expandedPath isDirectory:&isDir];
    
    int trackCount = 0;
    
    JukeboxData *jbData = [JukeboxData singleton];
    
    if (dirExists && &isDir) {
        NSArray *subpaths = [fileManager subpathsOfDirectoryAtPath:expandedPath error:NULL];
        NSLog(@"Size of subpaths = %lu", [subpaths count]);
        for (id obj in subpaths) {
            NSString *file = [NSString stringWithFormat:@"%@/%@", expandedPath, obj];
            BOOL isSubPathADir = NO;
            if ([FSAudioScanner hasAudioExtension:file] && [fileManager fileExistsAtPath:file isDirectory:&isSubPathADir] && ! isSubPathADir) {                  
                AudioTag *audioTag = [[AudioTag alloc] initFromFile:file];
                audioTag.path = [NSString stringWithFormat:@"/library/%@", obj];
                audioTag.server = [NSString stringWithFormat:@"localhost:%d", jukeboxConfig.port];
                if (audioTag) {
                    [jbData saveSong:audioTag isLocal:YES];
                    trackCount++;
                }
            }
        }
    }
    [fileManager release];
    
    [jbData cleanupLocalTracks];
    
    NSLog(@"Stored array of %d audio files", trackCount);
    [[TinyJukeboxAppDelegate singleton] setStatusToIndexComplete];
    
    [FSAudioScanner alertClients];
}

+ (void) alertClients {
    NSLog(@"Alering clients of local updates");
    
    JukeboxData *jbData = [JukeboxData singleton];
    
    for (id rc in [jbData remoteClients]) {
        NSString *client = (NSString *) rc;
        NSLog(@"Sending refresh message to %@", client);
        
        NSString *clientUrl = client;
        if (! [clientUrl hasPrefix:@"http://"]) {
            clientUrl = [NSString stringWithFormat:@"http://%@", client];
        }
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/refresh?server=%@", clientUrl, client]];
        NSString *method = @"GET";
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:method];
        [request setTimeoutInterval:30];
        NSURLResponse *response = [[NSURLResponse alloc] init];
        NSError *error = nil;
        [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error) {
            NSLog(@"%@", error);
        }
    }
}

@end
