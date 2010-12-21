/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKPoster.h - Posting data to the board.
 */

#import "CKPost.h"
#import "CKBoard.h"

// This struct will be deprecated in the near future as captchas will be handled by a class of their own.
typedef struct {
	NSString* challenge;
	NSImage* image;
	NSString* verification;
} captcha_s;

// Post attempt templates
static BOOL (^get)(int) = ^(int idno) { return (BOOL)((idno + 1) % (int)pow(10,(int)log10(idno)) == 0); };
static BOOL (^dubs)(int) = ^(int idno) { return (BOOL)!((idno + 1) % 100 % 11); };

@interface CKPoster : NSObject {
	NSURL* URL;
	NSURL* action;
	CKUser* user;
	NSString* subject;
	NSString* comment;
	NSString* file;
	captcha_s captcha;
	
	CKBoard* board; // For dubs
	NSMutableURLRequest* request;
}
@property(nonatomic,readwrite,copy) CKUser* user;
@property(nonatomic,readwrite,copy) NSString* subject;
@property(nonatomic,readwrite,copy) NSString* comment;
@property(nonatomic,readwrite,copy) NSString* file;
@property(nonatomic,readwrite,copy) NSString* verification;
@property(nonatomic,readonly,copy) NSImage* captcha;

- (id)initWithPostingDictionary:(NSDictionary*)dict;
+ (CKPoster*)posterWithDictionary:(NSDictionary*)dict;
- (id)initByReferencingURL:(NSURL*)url;
// No factory method for a reference poster, this doesn't seem necessary
- (id)initWithURL:(NSURL*)url;
+ (CKPoster*)posterForURL:(NSURL*)url;
- (id)initWithXML:(NSXMLNode*)doc;
+ (CKPoster*)posterForXML:(NSXMLNode*)doc;
- (void)dealloc;
- (int)populate;
- (void)populate:(NSXMLNode*)doc;

- (NSImage*)captcha;
- (BOOL)verify:(NSString*)captchaverification;
- (void)prepare;
- (CKPost*)post:(int*)error;
- (CKPost*)post:(int*)error attempt:(BOOL (^)(int idno))test;
@end
