//
//  TinyJukeboxAppDelegate.h
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/13/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class HTTPServer;
@class AudioStreamer;
@class JukeboxConfig;
@class AudioTag;
@class JukeboxWebsocket;

@interface TinyJukeboxAppDelegate : NSObject <NSApplicationDelegate> {
    NSWindow *window;
    NSMenu *statusMenu;
    NSMenuItem *rescanMenuItem;
    NSMenuItem *indexStatusMenuItem;
    NSStatusItem *statusItem;
    NSImage *trayImage;
    
    JukeboxConfig *jukeboxConfig;
    
    HTTPServer *httpServer;
    AudioStreamer *streamer;
    
    NSMutableArray *playlist;
    AudioTag *currentSong;
    NSMutableArray *webSockets;
}

@property (assign) IBOutlet NSWindow *window;
@property (assign) IBOutlet NSMenu *statusMenu;
@property (assign) IBOutlet NSMenuItem *rescanMenuItem;
@property (assign) IBOutlet NSMenuItem *indexStatusMenuItem;
@property (assign) JukeboxConfig *jukeboxConfig;
@property (assign) NSMutableArray *playlist;
@property (assign) AudioTag *currentSong;
@property (assign) NSMutableArray *webSockets;

// Initialize objects
+ (TinyJukeboxAppDelegate *) singleton;
- (void) loadConfig;
- (void) reloadServer;

// Menu actions
- (IBAction) rescan:(id)sender;
- (IBAction) openConfig:(id)sender;

// Actions invokable from HTTP
- (void) addToQueue:(NSString *)key;
- (void) stop;
- (void) pause;
- (void) addWebSocket:(JukeboxWebsocket *)websocket;
- (void) removeWebSocket:(JukeboxWebsocket *)websocket;
- (void) sendWebSocketsPlaylistUpdate;
- (NSArray *) getPlaylist;

// AudioStreamer control
- (void) playUrl: (NSString *)url;
- (void) destroyStreamer;
- (void) playbackStateChanged:(NSNotification *)aNotification;
- (void) playNextAndForceSkip:(BOOL)force;

// Notifications
- (void) postMainThreadNotificationWithName:(NSString *)name withUserInfo:(NSDictionary *)userInfo;
- (void) addToQueueNotification:(NSNotification *)aNotification;
- (void) stopNotification:(NSNotification *)aNotification;
- (void) pauseNotification:(NSNotification *)aNotification;
- (void) updateIndexStatus:(NSNotification *)aNotification;

// Updates
- (void) setStatusToIndexing;
- (void) setStatusToIndexComplete;

@end
