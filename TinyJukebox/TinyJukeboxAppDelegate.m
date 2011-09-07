//
//  TinyJukeboxAppDelegate.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/13/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "TinyJukeboxAppDelegate.h"
#import "HTTPServer.h"
#import "AudioStreamer.h"
#import "JukeboxHttpConnection.h"
#import "JukeboxConfig.h"
#import "AudioTag.h"
#import "JukeboxData.h"
#import "FSAudioScanner.h"
#import "JukeboxWebsocket.h"
#import "JukeboxPrefWindow.h"
#import "HttpAudioScanner.h"

@implementation TinyJukeboxAppDelegate

@synthesize window;
@synthesize statusMenu;
@synthesize rescanMenuItem;
@synthesize indexStatusMenuItem;
@synthesize jukeboxConfig;
@synthesize playlist;
@synthesize currentSong;
@synthesize webSockets;

#pragma mark Setup methods

static TinyJukeboxAppDelegate *singleton = nil;

+ (TinyJukeboxAppDelegate *) singleton {
    return singleton;
}

- (void) loadConfig {
    jukeboxConfig = [[JukeboxData singleton] getConfig];
    NSLog(@"Config reloaded.");
}

- (void) reloadServer {
    [self loadConfig];
    
    NSArray *addresses = [[NSHost currentHost] addresses];
    for (id a in addresses) {
        NSLog(@"Address %@", a);
    }
    
    NSLog(@"Name = %@", [[NSHost currentHost] localizedName]);
    
    if (httpServer && [httpServer isRunning]) {
        NSLog(@"Stopping http server");
        [httpServer stop];
        NSLog(@"Stopped http server");
    }
    
    if (httpServer) {
        [httpServer release];
        httpServer = nil;
    }
    
    NSLog(@"Initializing http server");
    httpServer = [[HTTPServer alloc] init];
	[httpServer setConnectionClass:[JukeboxHttpConnection class]];
	[httpServer setType:@"_http._tcp."];
	[httpServer setPort:jukeboxConfig.port];
    
    NSString *docRoot = [jukeboxConfig.localLibraryDirectory stringByExpandingTildeInPath];
	[httpServer setDocumentRoot:docRoot];
	
	NSError *error;
	BOOL success = [httpServer start:&error];
    NSLog(@"Started http server");
	
	if(!success) {
		NSLog(@"Error starting HTTP Server: %@", error);
	}
    
    if ([[JukeboxData singleton] getLocalTrackCount] == 0) {
        NSLog(@"No local tracks stored, initiating rescan");
        [self rescan:nil];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    singleton = self;
    
    // Load once to avoid lazy loading
    [JukeboxData singleton];
    
    webSockets = [[NSMutableArray alloc] init];
    playlist = [[NSMutableArray alloc] init];
    currentSong = nil;
    
    //[NSApp performSelector:@selector(terminate:) withObject:nil afterDelay:0.0];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(addToQueueNotification:) name:@"addToQueue" object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopNotification:) name:@"stop" object:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pauseNotification:) name:@"pause" object:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateIndexStatus:) name:@"updateIndexStatus" object:self];
    
    [self reloadServer];
}

-(void)awakeFromNib {
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    //[statusItem setTitle:@"Jukebox"];
    trayImage = [NSImage imageNamed:@"tinyjukebox.png"];
    [statusItem setImage:trayImage];
    [statusItem setAlternateImage:trayImage];
    [statusItem setHighlightMode:YES];
}

#pragma mark AudioStreamer control

- (void) playUrl:(NSString *)url {
    NSString *escapedValue =
    [(NSString *)CFURLCreateStringByAddingPercentEscapes(nil, (CFStringRef)url, NULL, NULL, kCFStringEncodingUTF8)
     autorelease];
    
    if (streamer) {
        [self destroyStreamer];
    }
	streamer = [[AudioStreamer alloc] initWithURL:[NSURL URLWithString:escapedValue]];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(playbackStateChanged:)
     name:ASStatusChangedNotification
     object:streamer];
    
    [streamer start];
}

- (void)playbackStateChanged:(NSNotification *)aNotification {
	if ([streamer isWaiting]) {
		NSLog(@"AudioStreamer is loading");
	}
	else if ([streamer isPlaying]) {
		NSLog(@"AudioStreamer is playing");
	}
	else if ([streamer isIdle]) {
        NSLog(@"AudioStreamer is finished");
		[self destroyStreamer];
        [self playNextAndForceSkip:NO];
	}
}

- (void) playNextAndForceSkip:(BOOL)force {
    if ([playlist count] == 0) {
        NSLog(@"Playlist is empty");
        currentSong = nil;
        [self sendWebSocketsPlaylistUpdate];
        return;
    }
    if (streamer && force) {
        [self destroyStreamer];
    }
    if (streamer && ! force) {
        return;
    }
    AudioTag *nextSong = [playlist objectAtIndex:0];
    if (nextSong != nil) {
        [self playUrl:nextSong.url];
        currentSong = nextSong;
        @synchronized(playlist) {
            [playlist removeObjectAtIndex:0];
        }
        [self sendWebSocketsPlaylistUpdate];
    } else {
        currentSong = nil;
    }
}

- (void)destroyStreamer {
	if (streamer) {
		[[NSNotificationCenter defaultCenter]
         removeObserver:self
         name:ASStatusChangedNotification
         object:streamer];
		
		[streamer stop];
		[streamer release];
		streamer = nil;
	}
}

#pragma make Actions invoked from HTTP

- (void) addToQueue:(NSString *)key {
    NSMutableDictionary *tmp = [[NSMutableDictionary alloc] initWithCapacity:1];
    [tmp setObject:key forKey:@"key"];
    [self postMainThreadNotificationWithName:@"addToQueue" withUserInfo:tmp];
}

- (void) stop {
    [self postMainThreadNotificationWithName:@"stop" withUserInfo:nil];
}

- (void) pause {
    [self postMainThreadNotificationWithName:@"pause" withUserInfo:nil];
}

- (void) addWebSocket:(JukeboxWebsocket *)websocket {
    @synchronized(webSockets) {
        [self.webSockets addObject:websocket];
        NSLog(@"Added websocket.");
    }
}

- (void) removeWebSocket:(JukeboxWebsocket *)websocket {
    @synchronized(webSockets) {
        [self.webSockets removeObject:websocket];
        NSLog(@"Removed websocket");
    }
}

- (void) sendWebSocketsPlaylistUpdate {
    @synchronized(webSockets) {
        for (id ws in webSockets) {
            [((JukeboxWebsocket *) ws) sendPlaylistUpdate];
        }
    }
}

- (void) sendWebSocketsPaused {
    @synchronized(webSockets) {
        for (id ws in webSockets) {
            [((JukeboxWebsocket *) ws) sendPaused];
        }
    }
}

- (void) sendWebSocketsPlaying {
    @synchronized(webSockets) {
        for (id ws in webSockets) {
            [((JukeboxWebsocket *) ws) sendPlaying];
        }
    }
}

#pragma mark Notification receivers

- (void) postMainThreadNotificationWithName:(NSString *)name withUserInfo:(NSDictionary *)userInfo {
    [[self class] performSelectorOnMainThread:@selector(postNotification:)
                                   withObject:[NSNotification notificationWithName:name object:self userInfo:userInfo] 
                                waitUntilDone:NO];
}

+ (void)postNotification:(NSNotification *)aNotification {
    [[NSNotificationCenter defaultCenter] postNotification:aNotification];
}

- (void)addToQueueNotification:(NSNotification *)aNotification {
    NSString *key = [aNotification.userInfo objectForKey:@"key"];
    if (key) {
        AudioTag *audioTag = [[JukeboxData singleton] getSongForKey:key];
        if (audioTag) {
            @synchronized(playlist) {
                [playlist addObject:audioTag];
            }
            NSLog(@"Adding %@", audioTag.title);
            if (! streamer) {
                [self playNextAndForceSkip:NO];
            }
            [self sendWebSocketsPlaylistUpdate];
        }
    }
}

- (void) stopNotification:(NSNotification *)aNotification {
    if (streamer) {
        [streamer stop];
    }
}

- (void) pauseNotification:(NSNotification *)aNotification {
    if (streamer) {
        [streamer pause];
        if ([streamer isPaused]) {
            [self sendWebSocketsPaused];
        } else {
            [self sendWebSocketsPlaying];
        }
    }
}

- (void) updateIndexStatus:(NSNotification *)aNotification {
    NSString *status = [aNotification.userInfo objectForKey:@"status"];
    if ([status isEqualToString:@"reindex"]) {
        [indexStatusMenuItem setTitle:@"Rescanning tracks..."];
        [rescanMenuItem setEnabled:NO];
    } else {
        [indexStatusMenuItem setTitle:@"All files indexed"];
        [rescanMenuItem setEnabled:YES];
    }
}

#pragma mark Utility

// Return a copy of the playlist for thread safety 
- (NSArray *) getPlaylist {
    @synchronized(playlist) {
        return [NSArray arrayWithArray:playlist]; 
    }
}


#pragma mark GUI actions

- (IBAction) openPlayer:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://localhost:%d", jukeboxConfig.port]]]; 
}

- (IBAction) rescan:(id)sender {
    [NSThread detachNewThreadSelector:@selector(rescan:) toTarget:[FSAudioScanner class] withObject:jukeboxConfig];
    [NSThread detachNewThreadSelector:@selector(rescan:) toTarget:[HttpAudioScanner class] withObject:nil];
}

- (IBAction) openConfig:(id)sender {
    [NSApp activateIgnoringOtherApps: YES];
    [[JukeboxPrefWindow sharedPrefsWindowController] showWindow:nil];
}

- (IBAction) about:(id)sender {
	// [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://github.com/mmattozzi/TinyJukebox"]];
    [NSApp activateIgnoringOtherApps: YES];
    [[NSApplication sharedApplication] orderFrontStandardAboutPanel:self];
}

- (void) setStatusToIndexing {
    NSMutableDictionary *tmp = [[NSMutableDictionary alloc] initWithCapacity:1];
    [tmp setObject:@"reindex" forKey:@"status"];
    [self postMainThreadNotificationWithName:@"updateIndexStatus" withUserInfo:tmp];
}

- (void) setStatusToIndexComplete {
    NSMutableDictionary *tmp = [[NSMutableDictionary alloc] initWithCapacity:1];
    [tmp setObject:@"complete" forKey:@"status"];
    [self postMainThreadNotificationWithName:@"updateIndexStatus" withUserInfo:tmp];
}

@end
