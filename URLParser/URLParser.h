//
//  URLParser.h
//  TinyJukebox
//
// From: http://iphone.demay-fr.net/2010/04/parsing-url-parameters-in-a-nsstring/
//

#import <Foundation/Foundation.h>


@interface URLParser : NSObject {
	NSArray *variables;
}

@property (nonatomic, retain) NSArray *variables;

- (id)initWithURLString:(NSString *)url;
- (NSString *)valueForVariable:(NSString *)varName;

@end
