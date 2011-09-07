//
//  JukeboxWebsocket.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/26/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "JukeboxWebsocket.h"
#import "TinyJukeboxAppDelegate.h"


@implementation JukeboxWebsocket

- (void)didOpen {
	[super didOpen];
	[[TinyJukeboxAppDelegate singleton] addWebSocket:self];
}

- (void)didReceiveMessage:(NSString *)msg {
}

- (void) sendPlaylistUpdate {
    [self sendMessage:@"Playlist updated"];
}

- (void) sendPaused {
    [self sendMessage:@"Paused"];
}

- (void) sendPlaying {
    [self sendMessage:@"Playing"];
}

- (void)didClose {
	[[TinyJukeboxAppDelegate singleton] removeWebSocket:self];
    [super didClose];
}


@end
