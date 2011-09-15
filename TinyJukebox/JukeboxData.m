//
//  JukeboxData.m
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/22/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "JukeboxData.h"
#import "FMDatabase.h"
#import "AudioTag.h"
#import "JukeboxConfig.h"

@implementation JukeboxData

static JukeboxData *singleton = nil;

/*
 From: http://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSObject_Class/Reference/Reference.html
 The runtime sends initialize to each class in a program exactly one time just before the class, or any class 
 that inherits from it, is sent its first message from within the program. (Thus the method may never be invoked 
 if the class is not used.) The runtime sends the initialize message to classes in a thread-safe manner. 
 Superclasses receive this message before their subclasses.
*/
+ (void)initialize {
    if (self == [JukeboxData class]) {
        singleton = [[self alloc] init];
    }
}

+ (JukeboxData *) singleton {
    return singleton;
}

+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (singleton == nil) {
            singleton = [super allocWithZone:zone];
            return singleton;
        }
    }
    
    return nil;
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (id)retain {
    return self;
}

- (void)release {
    // do nothing
}

- (id)autorelease {
    return self;
}

- (NSUInteger)retainCount {
    return NSUIntegerMax;
}

- (id)init {
    self = [super init];
    if (self) {
        localIndexGeneration = (long)[[NSDate date] timeIntervalSince1970];
        remoteIndexGeneration = localIndexGeneration;
        NSLog(@"Local index generation = %ld", localIndexGeneration);
        remoteClients = [[NSMutableSet alloc] init];
        dbPool = [FMDatabasePool databasePoolWithPath:[self pathForDataFile]];
        
        FMDatabase *db = [[dbPool db] popFromPool];
        if (! [db executeUpdate:@"CREATE TABLE IF NOT EXISTS tracks ( id text primary key, title text, album text, server text, artist text, trackNumber integer, path text, isLocal int, generation int )"]) {
            NSLog(@"%@", [db lastErrorMessage]);
        }
        if (! [db executeUpdate:@"CREATE TABLE IF NOT EXISTS servers ( id integer primary key, url text, type text, status text )"]) {
            NSLog(@"%@", [db lastErrorMessage]);
        }
        if (! [db executeUpdate:@"CREATE TABLE IF NOT EXISTS config ( directory text, port int, allowRemoteControl int, shareFiles int, hostname text )"]) {
            NSLog(@"%@", [db lastErrorMessage]);
        }
        
        FMResultSet *rs = [db executeQuery:@"SELECT * FROM config"];
        int configPresent = 0;
        if ([rs next]) {
            configPresent = 1;
        }
        [rs close];
        if (configPresent == 0) {
            [db executeUpdate:@"INSERT INTO config (directory, port, allowRemoteControl, shareFiles, hostname) VALUES (?, ?, ?, ?, ?)", 
             [@"~/Music" stringByExpandingTildeInPath], 
             [NSNumber numberWithInt:JUKEBOX_DEFAULT_PORT], 
             [NSNumber numberWithInt:1], 
             [NSNumber numberWithInt:1],
             [NSString stringWithFormat:@"%@.local", [[NSHost currentHost] localizedName]]];
        }
        
        [db pushToPool];
    }
    
    return self;
}

// Create a place to store the TinyJukebox data, if necessary. Either way, return the path of the file.
- (NSString *) pathForDataFile {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/TinyJukebox/";
    folder = [folder stringByExpandingTildeInPath];
    
    if ([fileManager fileExistsAtPath: folder] == NO) {
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:NO attributes:nil error:nil];
    }
    
    NSString *fileName = @"library.db";
    return [folder stringByAppendingPathComponent:fileName];    
}

- (void) addRemoteClient:(NSString *)client {
    NSLog(@"Adding remote client: %@", client);
    [remoteClients addObject:client];
}

- (NSSet *) remoteClients {
    return remoteClients;
}

#pragma mark Track queries

- (void) saveSong:(AudioTag *)audioTag isLocal:(BOOL)local {
    @synchronized(singleton) {
        [[dbPool db] executeUpdate:@"INSERT OR REPLACE INTO tracks (id, title, album, server, artist, trackNumber, path, isLocal, generation) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)", 
         [audioTag hashString], audioTag.title, audioTag.album, audioTag.server, audioTag.artist, audioTag.trackNumber, audioTag.path, 
         [NSNumber numberWithBool:local], (local ? [NSNumber numberWithLong:localIndexGeneration] : [NSNumber numberWithLong:remoteIndexGeneration])];
    }
}

/**
 * Deletes all tracks that weren't saved during the last local reindexing.
 */
- (void) cleanupLocalTracks {
    @synchronized(singleton) {
        [[dbPool db] executeUpdate:@"DELETE FROM tracks WHERE generation != ? AND isLocal = 1", [NSNumber numberWithLong:localIndexGeneration]];
        localIndexGeneration = (long)[[NSDate date] timeIntervalSince1970];
    }
}

/**
 * Deletes all tracks that weren't saved during the last remote reindexing.
 */
- (void) cleanupRemoteTracks {
    @synchronized(singleton) {
        [[dbPool db] executeUpdate:@"DELETE FROM tracks WHERE generation != ? AND isLocal = 0", [NSNumber numberWithLong:remoteIndexGeneration]];
        remoteIndexGeneration = (long)[[NSDate date] timeIntervalSince1970];
    }
}

/**
 * Assumes next has already been called on rs and data is ready to be read.
 */
+ (AudioTag *) audioTagFromResultSet:(FMResultSet *)rs {
    AudioTag *audioTag = [[AudioTag alloc] init];
    audioTag.title = [rs stringForColumn:@"title"];
    audioTag.album = [rs stringForColumn:@"album"];
    audioTag.server = [rs stringForColumn:@"server"];
    audioTag.artist = [rs stringForColumn:@"artist"];
    audioTag.trackNumber = [NSNumber numberWithInt:[rs intForColumn:@"trackNumber"]];
    audioTag.path = [rs stringForColumn:@"path"];
    return audioTag;
}

+ (NSArray *) audioTagArrayFromResultSet:(FMResultSet *)rs {
    NSMutableArray *result = [[NSMutableArray alloc] init];
    while ([rs next]) {
        [result addObject:[JukeboxData audioTagFromResultSet:rs]];
    }
    return result;
}

- (NSArray *) getLocalSongs {
    @synchronized(singleton) {
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT title, album, server, artist, trackNumber, path FROM tracks WHERE isLocal = 1 ORDER BY artist, album, trackNumber"];
        NSArray *songs = [JukeboxData audioTagArrayFromResultSet:rs];
        [rs close];
        return songs;
    }
}

- (NSArray *) getAllSongs {
    @synchronized(singleton) {
        NSLog(@"Opening sqlite query");
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT title, album, server, artist, trackNumber, path FROM tracks ORDER BY artist, album, trackNumber"];
        NSArray *songs = [JukeboxData audioTagArrayFromResultSet:rs];
        [rs close];
        NSLog(@"Finished sqlite query");
        return songs;
    }
}

- (AudioTag *) getSongForKey:(NSString *)key {
    @synchronized(singleton) {
        NSString *keyCopy = [NSString stringWithString:key];
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT title, album, server, artist, trackNumber, path FROM tracks WHERE id = ?", keyCopy];
        if ([rs next]) {
            AudioTag *audioTag = [JukeboxData audioTagFromResultSet:rs];
            [rs close];
            return audioTag;
        } else {
            return nil;
        }
    }
}

- (FMResultSet *) executeQuery:(NSString *)query withFilters:(NSDictionary *)filters {
    NSMutableArray *args = [[[NSMutableArray alloc] init] autorelease];
    NSString *queryPredicate = @"WHERE ";
    
    NSString *server = [filters valueForKey:@"server"];
    if (server != nil) {
        queryPredicate = [queryPredicate stringByAppendingString:@"server like ? "];
        [args addObject:server];
    }
    NSString *artist = [filters valueForKey:@"artist"];
    if (artist != nil) {
        if ([args count] > 0) {
            queryPredicate = [queryPredicate stringByAppendingString:@"AND "];
        }
        queryPredicate = [queryPredicate stringByAppendingString:@"artist like ? "];
        [args addObject:artist];
    }
    NSString *album = [filters valueForKey:@"album"];
    if (album != nil) {
        if ([args count] > 0) {
            queryPredicate = [queryPredicate stringByAppendingString:@"AND "];
        }
        queryPredicate = [queryPredicate stringByAppendingString:@"album like ? "];
        [args addObject:album];
    }
    
    if ([args count] == 0) {
        queryPredicate = @"";
    }
    
    NSLog(@"Args = %@", args);
    NSString *qry = [NSString stringWithFormat:query, queryPredicate];
    NSLog(@"Query = %@", qry);
    FMResultSet *rs = [[dbPool db] executeQuery:qry withArgumentsInArray:args];
    return rs;
}

- (NSArray *) getSongsWithFilters:(NSDictionary *)filters {
    @synchronized(singleton) {
        FMResultSet *rs = [self executeQuery:@"SELECT title, album, server, artist, trackNumber, path FROM tracks %@ ORDER BY artist, album, trackNumber" withFilters:filters];
        NSArray *songs = [JukeboxData audioTagArrayFromResultSet:rs];
        [rs close];
        return songs;
    }
}

- (NSArray *) getServers {
    @synchronized(singleton) {
        NSMutableArray *servers = [[[NSMutableArray alloc] init] autorelease];
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT distinct(server) AS s FROM tracks"];
        while ([rs next]) {
            NSString *o = [rs stringForColumn:@"s"];
            if (o) {
                [servers addObject:o];
            }
        }
        [rs close];
        return servers;
    }
}

- (NSArray *) getArtistsWithFilters:(NSDictionary *)filters {
    @synchronized(singleton) {
        NSMutableArray *artists = [[[NSMutableArray alloc] init] autorelease];
        FMResultSet *rs = [self executeQuery:@"SELECT distinct(artist) FROM tracks %@ ORDER BY artist" withFilters:filters];
        while ([rs next]) {
            NSString *o = [rs stringForColumn:@"artist"];
            if (o) {
                [artists addObject:o];
            }
        }
        [rs close];
        return artists;
    }
}

- (NSArray *) getAlbumsWithFilters:(NSDictionary *)filters {
    @synchronized(singleton) {
        NSMutableArray *albums = [[[NSMutableArray alloc] init] autorelease];
        FMResultSet *rs = [self executeQuery:@"SELECT distinct(album) FROM tracks %@ ORDER BY album" withFilters:filters];
        while ([rs next]) {
            NSString *o = [rs stringForColumn:@"album"];
            if (o) {
                [albums addObject:o];
            }
        }
        [rs close];
        return albums;
    }
}

- (int) getLocalTrackCount {
    @synchronized(singleton) {
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT count(*) AS c FROM tracks WHERE isLocal = 1"];
        int count = 0;
        if ([rs next]) {
            count = [rs intForColumn:@"c"];
        }
        [rs close];
        return count;
    }
}

#pragma mark Server queries

- (int) getServerCount {
    @synchronized(singleton) {
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT count(*) AS c FROM servers"];
        int count = 0;
        if ([rs next]) {
            count = [rs intForColumn:@"c"];
        }
        [rs close];
        return count;
    }
}

- (NSString *) getServerValueForColumn:(NSString *) column row:(NSInteger)row {
    @synchronized(singleton) {
        FMResultSet *rs = [[dbPool db] executeQuery:[NSString stringWithFormat:@"SELECT * FROM servers LIMIT 1 OFFSET %ld", row]];
        NSString *value = nil;
        if ([rs next]) {
            value = [rs stringForColumn:column];
        }
        [rs close];
        return value;
    }
}

- (void) addServerUrl:(NSString *)url withType:(NSString *)type {
    @synchronized(singleton) {
        [[dbPool db] executeUpdate:@"INSERT INTO servers (url, type) VALUES (?, ?)", url, type];
    }
}

- (NSArray *) getRemoteServerUrls {
    NSMutableArray *serverUrls = [[[NSMutableArray alloc] init] autorelease];
    @synchronized(singleton) {
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT url FROM servers WHERE type = 'Manual'"];
        while ([rs next]) {
            [serverUrls addObject:[rs stringForColumn:@"url"]];
        }
        [rs close];
    }
    return serverUrls;
}

- (void) deleteServerForRow:(NSInteger)row {
    @synchronized(singleton) {
        FMDatabase *db = [[dbPool db] popFromPool];
        FMResultSet *rs = [db executeQuery:[NSString stringWithFormat:@"SELECT * FROM servers LIMIT 1 OFFSET %ld", row]];
        NSNumber *serverId = nil;
        if ([rs next]) {
            serverId = [NSNumber numberWithInt:[rs intForColumn:@"id"]];
        }
        [rs close];
        if (serverId > 0) {
            [db executeUpdate:@"DELETE FROM servers WHERE id = ?", serverId];
            if ([db lastErrorMessage]) {
                NSLog(@"Error: %@", [db lastErrorMessage]);
            }
        }
        [db pushToPool];
    }
}

- (JukeboxConfig *)getConfig {
    @synchronized(singleton) {
        FMResultSet *rs = [[dbPool db] executeQuery:@"SELECT * FROM config LIMIT 1"];
        JukeboxConfig *config = nil;
        if ([rs next]) {
            config = [[[JukeboxConfig alloc] initWithDirectory:[rs stringForColumn:@"directory"] 
                                                          port:[rs intForColumn:@"port"] 
                                            allowRemoteControl:[rs intForColumn:@"allowRemoteControl"] 
                                                    shareFiles:[rs intForColumn:@"shareFiles"]
                                                      hostname:[rs stringForColumn:@"hostname"]] autorelease];
        }
        [rs close];
        return config;
    }
}

- (void) saveConfig:(JukeboxConfig *)config {
    @synchronized(singleton) {
        NSNumber *portNumber = [NSNumber numberWithInt:config.port];
        NSNumber *allowRemoteNumber = [NSNumber numberWithBool:config.allowRemoteControl];
        NSNumber *shareFilesNumber = [NSNumber numberWithBool:config.shareFiles];
        FMDatabase *db = [[dbPool db] popFromPool];
        if (! [db executeUpdate:@"UPDATE config SET directory = ?, port = ?, allowRemoteControl = ?, shareFiles = ?, hostname = ?", 
               config.localLibraryDirectory, portNumber, allowRemoteNumber, shareFilesNumber, config.hostname]) {
            NSLog(@"%@", [db lastErrorMessage]);
        }
        
        [db pushToPool];
    }
}

- (void)dealloc
{
    [dbPool releaseAllDatabases];
    [super dealloc];
}

@end
