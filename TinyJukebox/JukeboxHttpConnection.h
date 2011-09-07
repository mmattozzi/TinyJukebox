//
//  JukeboxHttpConnection.h
//  SimpleJukebox
//
//  Created by Michael Mattozzi on 6/12/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HTTPConnection.h"

@interface JukeboxHttpConnection : HTTPConnection

+ (NSDictionary *) extractParametersFromPath:(NSString *)path;

@end
