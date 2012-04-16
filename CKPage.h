/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKPage.h - A single page.
 */

@class CKPost;
@class CKThread;

@interface CKPage : NSObject {
	NSURL* URL;
	NSString* board;
	int index;
	NSMutableArray* threads;	
}
@property(nonatomic,readonly) NSURL* URL;
@property(nonatomic,readonly) NSString* board;
@property(nonatomic,readonly) int index;
@property(nonatomic,readonly) NSArray* threads;

- (id)initByReferencingURL:(NSURL*)url;
+ (CKPage*)pageReferencingURL:(NSURL*)url;
- (id)initWithURL:(NSURL*)url;
+ (CKPage*)pageFromURL:(NSURL*)url;
- (id)initWithXML:(NSXMLDocument*)doc;
+ (CKPage*)pageFromXML:(NSXMLDocument*)doc;
- (void)dealloc;
- (int)populate;
- (void)populate:(NSXMLDocument*)doc;

- (CKThread*)getThread:(int)index; // Replacement for objectAtIndex: which ensures a populated thread
- (CKPost*)newestPost;
- (CKPost*)oldestPost;
- (NSTimeInterval)rangeOfPosts;

- (NSString*)prettyPrint;
@end
