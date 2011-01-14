/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2009-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKUtil.h - Utility string/URL/network methods. Globally included.
 */

#import <CommonCrypto/CommonDigest.h>
#import "CKRecipe.h"

@interface CKUtil : NSObject 

+ (NSString*)parseBoard:(NSURL*)URL;
+ (NSString*)parseBoardFromString:(NSString*)URL;

+ (int)parseThreadID:(NSURL*)URL;
+ (NSURL*)URLByDeletingFragment:(NSURL*)URL;
+ (NSURL*)changePost:(NSURL*)original toPost:(int)idno;

+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL throughProxy:(NSURL*)proxy;
+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL;
+ (NSString*)version;

+ (NSString*)generatePassword;
+ (NSString*)MD5:(NSData*)data;

+ (void)setProxy:(NSURL*)proxy onRequest:(ASIHTTPRequest**)request;
+ (BOOL)checkBan:(NSXMLDocument*)doc;
@end
