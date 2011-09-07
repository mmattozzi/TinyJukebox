//
//  Util.h
//  TinyJukebox
//
//  Created by Michael Mattozzi on 6/25/11.
//  Copyright 2011 Michael Mattozzi. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface Util : NSObject {
    
}

+(NSString *) sha256HashStringFromSeedData:(NSString *)seedData;

@end
