//
//  JukeboxHttpConnection.m
//  SimpleJukebox
//
//  Created by Michael Mattozzi on 6/12/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "JukeboxHttpConnection.h"
#import "HTTPDynamicFileResponse.h"
#import "HTTPDataResponse.h"
#import "HTTPLogging.h"
#import "TinyJukeboxAppDelegate.h"
#import "JukeboxConfig.h"
#import "AudioTag.h"
#import "SBJson.h"
#import "JukeboxData.h"
#import "URLParser.h"
#import "Util.h"
#import "JukeboxWebsocket.h"
#import "HttpAudioScanner.h"

@implementation JukeboxHttpConnection

+ (NSDictionary *) extractParametersFromPath:(NSString *)path {
    URLParser *parser = [[[URLParser alloc] initWithURLString:path] autorelease];
    NSMutableDictionary *songQueryParams = [[[NSMutableDictionary alloc] init] autorelease];
    NSString *server = [parser valueForVariable:@"server"];
    if (server) {
        [songQueryParams setObject:[server stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:@"server"];
    }
    NSString *artist = [parser valueForVariable:@"artist"];
    if (artist) {
        [songQueryParams setObject:[artist stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:@"artist"];
    }
    NSString *album = [parser valueForVariable:@"album"];
    if (album) {
        [songQueryParams setObject:[album stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] forKey:@"album"];
    }
    return songQueryParams;
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    NSLog(@"Thread (%@) Got request: %@", [NSThread currentThread], path);
	NSString *filePath = [self filePathForURI:path];
	NSString *documentRoot = [config documentRoot];
    NSString *relativePath = [filePath substringFromIndex:[documentRoot length]];
    
    if (relativePath && [relativePath hasPrefix:@"/api/library"]) {
        
        JukeboxData *jbData = [JukeboxData singleton];
        NSDictionary *params = [JukeboxHttpConnection extractParametersFromPath:path];
        if ([params objectForKey:@"server"] != nil) {
            [jbData addRemoteClient:[params objectForKey:@"server"]];
        }
        
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        NSString *response = [jsonWriter stringWithObject:[jbData getLocalSongs]];
        
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
    
    } else if (relativePath && [relativePath hasPrefix:@"/api/playable"]) {
        
        NSDictionary *songQueryParams = [JukeboxHttpConnection extractParametersFromPath:path];
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        NSString *response = [jsonWriter stringWithObject:[[JukeboxData singleton] getSongsWithFilters:songQueryParams]];
        
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
    
    } else if (relativePath && [relativePath hasPrefix:@"/api/refresh"]) {
        
        NSDictionary *params = [JukeboxHttpConnection extractParametersFromPath:path];
        NSString *server = (NSString *) [params objectForKey:@"server"];
        if (server != nil) {
            NSLog(@"Got request to refresh %@", server);
            [NSThread detachNewThreadSelector:@selector(rescan:) toTarget:[HttpAudioScanner class] withObject:nil];
        }
        
        return [[[HTTPDataResponse alloc] initWithData:[@"{\"response\": \"OK\"}" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [relativePath hasPrefix:@"/api/artists"]) {
            
        NSDictionary *songQueryParams = [JukeboxHttpConnection extractParametersFromPath:path];
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        NSString *response = [jsonWriter stringWithObject:[[JukeboxData singleton] getArtistsWithFilters:songQueryParams]];
        
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [relativePath hasPrefix:@"/api/albums"]) {
        
        NSDictionary *songQueryParams = [JukeboxHttpConnection extractParametersFromPath:path];
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        NSString *response = [jsonWriter stringWithObject:[[JukeboxData singleton] getAlbumsWithFilters:songQueryParams]];
        
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [relativePath hasPrefix:@"/api/servers"]) {
        
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        NSString *response = [jsonWriter stringWithObject:[[JukeboxData singleton] getServers]];
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [relativePath isEqualToString:@"/api/queue"]) {
        
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        NSString *response = [jsonWriter stringWithObject:[[TinyJukeboxAppDelegate singleton] getPlaylist]];
        
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [relativePath isEqualToString:@"/api/playing"]) {
        
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        AudioTag *currentSong = [TinyJukeboxAppDelegate singleton].currentSong;
        NSString *response = nil;
        if (currentSong) {
            response = [jsonWriter stringWithObject:currentSong];
        } else {
            AudioTag *a = [[[AudioTag alloc] init] autorelease];
            a.title = @"TINYJUKEBOX_NOTHING";
            response = [jsonWriter stringWithObject:a];
        }
        
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [relativePath isEqualToString:@"/api/playlist"]) {
        
        SBJsonWriter *jsonWriter = [[[SBJsonWriter alloc] init] autorelease];
        AudioTag *currentSong = [TinyJukeboxAppDelegate singleton].currentSong;
        
        if (! currentSong) {
            AudioTag *a = [[[AudioTag alloc] init] autorelease];
            a.title = @"TINYJUKEBOX_NOTHING";
            currentSong = a;
        }
        NSString *hash = [NSString stringWithString:[currentSong hashString]];
        NSArray *queue = [[TinyJukeboxAppDelegate singleton] getPlaylist];
        for (AudioTag *a in queue) {
            hash = [hash stringByAppendingString:[a hashString]];
        }
        NSString *allHashed = [Util sha256HashStringFromSeedData:hash];
        
        NSDictionary *responseDict = [NSDictionary dictionaryWithObjectsAndKeys:
            allHashed, @"hash",
            currentSong, @"playing",
         queue, @"queue", nil];
        
        NSString *response = [jsonWriter stringWithObject:responseDict];
        return [[[HTTPDataResponse alloc] initWithData:[response dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
    
    } else if (relativePath && [ relativePath hasPrefix:@"/api/addToQueue/"]) {
        
        NSString *key = [relativePath substringFromIndex:16];
        [[TinyJukeboxAppDelegate singleton] addToQueue:key];
        return [[[HTTPDataResponse alloc] initWithData:[@"{\"response\": \"OK\"}" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (relativePath && [ relativePath hasPrefix:@"/api/addAlbumToQueue"]) {
        
        NSDictionary *songQueryParams = [JukeboxHttpConnection extractParametersFromPath:path];
        NSArray *songs = [[JukeboxData singleton] getSongsWithFilters:songQueryParams];
        for (id song in songs) {
            [[TinyJukeboxAppDelegate singleton] addToQueue:[((AudioTag *) song) hashString]];
        }
        
    } else if (relativePath && [relativePath isEqualToString:@"/api/stop"]) {
        
        [[TinyJukeboxAppDelegate singleton] stop];
        return [[[HTTPDataResponse alloc] initWithData:[@"{\"response\": \"OK\"}" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
    } else if (relativePath && [relativePath isEqualToString:@"/api/pause"]) {
    
        [[TinyJukeboxAppDelegate singleton] pause];
        return [[[HTTPDataResponse alloc] initWithData:[@"{\"response\": \"OK\"}" dataUsingEncoding:NSUTF8StringEncoding]] autorelease];
        
    } else if (!relativePath || ! [relativePath hasPrefix:@"/library"]) {
		
        NSLog(@"%@[%p]: Serving up dynamic content", THIS_FILE, self);
		
		NSString *computerName = [[NSHost currentHost] localizedName];
		NSString *currentTime = [[NSDate date] description];
		
		NSMutableDictionary *replacementDict = [NSMutableDictionary dictionaryWithCapacity:3];
		
		[replacementDict setObject:computerName forKey:@"COMPUTER_NAME"];
		[replacementDict setObject:currentTime  forKey:@"TIME"];
		[replacementDict setObject:[TinyJukeboxAppDelegate singleton].jukeboxConfig.localLibraryDirectory forKey:@"LOCAL_DIR"];
		
        if (! relativePath || [relativePath isEqualToString:@"/"]) {
            relativePath = @"/index.html";
        }
        
        NSString *fullPath = [NSString stringWithFormat:@"Web/%@", relativePath];
        // NSString *webPath = [[[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:fullPath] autorelease];
        
        NSString *webPath = [NSString stringWithFormat:@"/Users/mmattozzi/workspace/TinyJukebox/%@", fullPath];
        
		return [[[HTTPDynamicFileResponse alloc] initWithFilePath:webPath
		                                            forConnection:self
		                                                separator:@"%%"
		                                    replacementDictionary:replacementDict] autorelease];
	} 
	
    /** Handle all requests to file system */
    
    path = [path stringByReplacingOccurrencesOfString:@"/library" withString:@"" options:nil range:NSMakeRange(0, 8)];
    NSLog(@"Looking up %@ from FS", path);
    
	if (![filePath hasPrefix:documentRoot]) {
		// This will end up becoming a 404
		return nil;
	}
    
    // Just serve the file from a directory given the path
	return [super httpResponseForMethod:method URI:path];
}

- (WebSocket *)webSocketForURI:(NSString *)path {
	if([path isEqualToString:@"/updater"]) {
		return [[[JukeboxWebsocket alloc] initWithRequest:request socket:asyncSocket] autorelease];		
	}
	
	return [super webSocketForURI:path];
}

@end
