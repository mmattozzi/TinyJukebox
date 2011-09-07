//
//  AudioTagReader.m
//  SimpleJukebox
//
//  Created by Michael Mattozzi on 6/12/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import "AudioTag.h"
#include <AudioToolbox/AudioToolbox.h>
#import "Util.h"

@implementation AudioTag

@synthesize artist;
@synthesize album;
@synthesize title;
@synthesize trackNumber;
@synthesize server;
@synthesize path;

-(id) init {
    return [super init];
}

-(id) initFromFile:(NSString *)file {
    self = [super init];
    if (self) {
        AudioFileID fileID  = nil;
        OSStatus err        = noErr;
        
        NSURL * fileURL = [NSURL fileURLWithPath:file];
        err = AudioFileOpenURL( (CFURLRef) fileURL, kAudioFileReadPermission, 0, &fileID );
        if( err != noErr ) {
            AudioFileClose(fileID);
            return nil;
        }
        
        CFDictionaryRef piDict = nil;
        UInt32 piDataSize   = sizeof( piDict );
        
        err = AudioFileGetProperty( fileID, kAudioFilePropertyInfoDictionary, &piDataSize, &piDict );
        if( err != noErr ) {
            AudioFileClose(fileID);
            return nil;
        }
        
        self.artist = [(NSDictionary*)piDict objectForKey:[NSString stringWithUTF8String: kAFInfoDictionary_Artist]];
        self.album = [(NSDictionary*)piDict objectForKey:[NSString stringWithUTF8String: kAFInfoDictionary_Album]];
        self.title = [(NSDictionary*)piDict objectForKey:[NSString stringWithUTF8String: kAFInfoDictionary_Title]];
        NSString *tn = [(NSDictionary*)piDict objectForKey:[NSString stringWithUTF8String: kAFInfoDictionary_TrackNumber]];
        if (tn) {
            self.trackNumber = [NSNumber numberWithLong:[tn integerValue]];
        } else {
            self.trackNumber = [NSNumber numberWithLong:0];
        }
        
        AudioFileClose(fileID);
        
        if (self.title == nil || [self.title isEqualToString:@""]) {
            // Set the title to the filename instead of nothing
            self.title = [[file lastPathComponent] stringByDeletingPathExtension];
        }
        
        if (self.album == nil || [self.album isEqualToString:@""]) {
            self.album = @"Unknown Album";
        }
        
        CFRelease( piDict );
    }
    
    return self;
}

-(NSString *) hashString {
    NSString *seedData = [NSString stringWithFormat:@"%@-%@-%@-%@-%@", artist, album, title, server, path];
    return [Util sha256HashStringFromSeedData:seedData];
}

-(NSString *) url {
    return [NSString stringWithFormat:@"http://%@%@", server, path];
}

- (id)proxyForJson {
    return [NSDictionary dictionaryWithObjectsAndKeys:
        [self hashString], @"id",
        (artist ? artist : @"Unknown Artist"), @"artist",
        (album ? album : @"Unknown Album"), @"album",
        title, @"title", // Title will never be nil
        server, @"server", // Server will never be nil
        path, @"path", // Path will never be nil
        trackNumber, @"trackNumber", // If trackNumber is nil, just stop building dict right here
        nil];
}

- (void) dealloc {
    [artist release];
    [album release];
    [title release];
    [server release];
    [path release];
}

@end
