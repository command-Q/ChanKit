/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKPage.h - A single page.
 */

#import "CKThread.h"

@interface CKPage : NSObject {
	NSURL* URL;
	NSString* board;
	int index;
	NSMutableArray* threads;	
}
@property(nonatomic,readonly,copy) NSURL* URL;
@property(nonatomic,readonly,copy) NSString* board;
@property(nonatomic,readonly,assign) int index;
@property(nonatomic,readonly,copy) NSArray* threads;

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

@end
