/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2011 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKUtil.h - Utility string/URL/network methods. Globally included.
 */

@class ASIHTTPRequest;
@class CKRecipe;

@interface CKUtil : NSObject 

+ (NSString*)version;
+ (NSString*)describeError:(int)errnum;

+ (int)parsePostID:(NSURL*)URL;
+ (int)parseThreadID:(NSURL*)URL;
+ (int)parsePage:(NSURL*)URL;
+ (NSString*)parseBoard:(NSURL*)URL;
+ (NSURL*)parseBoardRoot:(NSURL*)URL;
+ (NSURL*)URLByDeletingFragment:(NSURL*)URL;

+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL throughProxy:(NSURL*)proxy;
+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL;
+ (int)validateResponse:(ASIHTTPRequest*)response;
+ (void)setProxy:(NSURL*)proxy onRequest:(ASIHTTPRequest**)request;
+ (BOOL)checkBan:(NSXMLDocument*)doc;

+ (NSString*)generatePassword;
+ (NSString*)MD5:(NSData*)data;

@end
