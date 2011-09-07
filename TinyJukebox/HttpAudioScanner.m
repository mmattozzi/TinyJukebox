//
//  HttpAudioScanner.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 7/6/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "HttpAudioScanner.h"
#import "JukeboxData.h"
#import "SBJson.h"
#import "AudioTag.h"

@implementation HttpAudioScanner

+ (void) rescan:(id)param {
    JukeboxData *jbData = [JukeboxData singleton];
    JukeboxConfig *jbConfig = [jbData getConfig];
    NSArray *servers = [[JukeboxData singleton] getRemoteServerUrls];
    
    for (id s in servers) {
        NSString *server = (NSString *) s;
        
        if (! [server hasPrefix:@"http://"]) {
            server = [NSString stringWithFormat:@"http://%@", server];
        }
        
        NSLog(@"Retrieving library from server %@", server);
        
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/api/library?server=%@:%d", server, jbConfig.hostname, jbConfig.port]];
        NSString *method = @"GET";
        NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:method];
        [request setTimeoutInterval:30];
        NSURLResponse *response = [[NSURLResponse alloc] init];
        NSError *error = nil;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
        if (error) {
            NSLog(@"%@", error);
        } else {
            SBJsonParser *parser = [[SBJsonParser alloc] init];
			NSArray *jsonObj = (NSArray *) [parser objectWithString:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
            NSLog(@"Saving %lu remote tracks", [jsonObj count]);
            for (id i in jsonObj) {
                NSDictionary *item = (NSDictionary *) i;
                AudioTag *audioTag = [[AudioTag alloc] init];
                audioTag.title = [item objectForKey:@"title"];
                audioTag.album = [item objectForKey:@"album"];
                audioTag.server = [NSString stringWithFormat:@"%@:%@", [url host], [url port]];
                audioTag.artist = [item objectForKey:@"artist"];
                audioTag.trackNumber = [item objectForKey:@"trackNumber"];
                audioTag.path = [item objectForKey:@"path"];
                
                [jbData saveSong:audioTag isLocal:NO];
            }
        }
    }
    
    [jbData cleanupRemoteTracks];
    NSLog(@"Complete remote reindex");
}

@end
