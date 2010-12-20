/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKThread.h - Thread object. May be initialized from thread XML or preinitialized from page XML.
 */

#import "CKPost.h"

@interface CKThread : NSObject {
	NSURL* URL;
	NSString* board;
	int ID;
	NSMutableArray* posts;
	int postcount;
	int imagecount;
	BOOL initialized; //Whether the thread is fully populated
}
@property(nonatomic,readonly,copy) NSURL* URL;
@property(nonatomic,readonly,assign) int ID;
@property(nonatomic,readonly,copy) NSString* board;
@property(nonatomic,readonly,copy) NSArray* posts;
@property(nonatomic,readonly,assign) int postcount;
@property(nonatomic,readonly,assign) int imagecount;
@property(nonatomic,readonly,retain) CKPost* OP;
@property(nonatomic,readonly,retain) CKPost* latest;
@property(nonatomic,readwrite,assign) BOOL sticky;
@property(nonatomic,readwrite,assign) BOOL closed;
@property(nonatomic,readonly,assign) BOOL initialized;

- (id)initByReferencingURL:(NSURL*)url;
+ (CKThread*)threadReferencingURL:(NSURL*)url;
- (id)initWithPage:(NSXMLDocument*)doc;
+ (CKThread*)threadFromPage:(NSXMLDocument*)doc;
- (id)initWithURL:(NSURL*)url;
+ (CKThread*)threadFromURL:(NSURL*)url;
- (void)dealloc;
- (int)populate;
- (void)populate:(NSXMLDocument*)doc;

- (CKPost*)postWithID:(int)idno;
- (BOOL)isBy:(CKUser*)author;
- (NSArray*)postsBy:(CKUser*)author;
- (NSArray*)postsExcluding:(CKUser*)author;
- (NSArray*)postsQuoting:(CKPost*)post;
- (NSArray*)postsFromIndex:(int)idex;

- (NSArray*)imagePosts;
- (NSArray*)images;

- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
@end
