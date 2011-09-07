//
//  AudioTagReader.h
//  SimpleJukebox
//
//  Created by Michael Mattozzi on 6/12/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface AudioTag : NSObject {
    NSString *artist;
    NSString *album;
    NSString *title;
    NSNumber *trackNumber;
    
    NSString *server;
    NSString *path;
}

@property (retain) NSString *artist;
@property (retain) NSString *album;
@property (retain) NSString *title;
@property (retain) NSString *server;
@property (retain) NSNumber *trackNumber;
@property (retain) NSString *path;

-(id) initFromFile:(NSString *)file;
-(NSString *) hashString;
-(NSString *) url;

@end
