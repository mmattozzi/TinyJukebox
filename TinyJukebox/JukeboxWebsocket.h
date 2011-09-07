//
//  JukeboxWebsocket.h
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/26/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebSocket.h"

@interface JukeboxWebsocket : WebSocket {
    
}

- (void) sendPlaylistUpdate;
- (void) sendPaused;
- (void) sendPlaying;

@end
