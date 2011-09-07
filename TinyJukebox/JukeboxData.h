//
//  JukeboxData.h
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/22/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>

#define JUKEBOX_DEFAULT_PORT 9033

@class FMDatabase;
@class AudioTag;
@class JukeboxConfig;

@interface JukeboxData : NSObject {
    FMDatabase *db;
    long localIndexGeneration;
    long remoteIndexGeneration;
    NSMutableSet *remoteClients;
}

+ (JukeboxData *) singleton;
- (NSString *) pathForDataFile;
- (void) addRemoteClient:(NSString *)client;
- (NSSet *) remoteClients;
- (void) saveSong:(AudioTag *)audioTag isLocal:(BOOL)local;
- (void) cleanupLocalTracks;
- (void) cleanupRemoteTracks;
- (NSArray *) getAllSongs;
- (NSArray *) getLocalSongs;
- (AudioTag *) getSongForKey:(NSString *)key;
- (NSArray *) getSongsWithFilters:(NSDictionary *)filters;
- (NSArray *) getServers;
- (NSArray *) getArtistsWithFilters:(NSDictionary *)filters;
- (NSArray *) getAlbumsWithFilters:(NSDictionary *)filters;
- (int) getLocalTrackCount;

- (int) getServerCount;
- (NSString *) getServerValueForColumn:(NSString *) column row:(NSInteger)row;
- (void) addServerUrl:(NSString *)url withType:(NSString *)type;
- (void) deleteServerForRow:(NSInteger)row;
- (NSArray *) getRemoteServerUrls;

- (JukeboxConfig *)getConfig;
- (void) saveConfig:(JukeboxConfig *)config;

@end
