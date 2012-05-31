/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKThread.h - Thread object. May be initialized from thread XML or preinitialized from page XML.
 */

@class CKPost;
@class CKUser;

@interface CKThread : NSObject {
	NSURL* URL;
	NSString* board;
	int ID;
	NSMutableArray* posts;
	int postcount;
	int imagecount;
	BOOL initialized; //Whether the thread is fully populated
}

@property(nonatomic,readonly) NSURL* URL;
@property(nonatomic,readonly) int ID;
@property(nonatomic,readonly) NSString* board;
@property(nonatomic,readonly) NSArray* posts;
@property(nonatomic,readonly) int postcount;
@property(nonatomic,readonly) int imagecount;
@property(nonatomic,readonly) CKPost* OP;
@property(nonatomic,readonly) NSArray* replies;
@property(nonatomic,readonly) CKPost* latest;
@property(nonatomic,readonly) BOOL sticky;
@property(nonatomic,readonly) BOOL closed;
@property(nonatomic,readonly) BOOL initialized;
@property(nonatomic,readonly) NSString* IDString;

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

- (NSString*)description;
- (NSString*)prettyPrint;
- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;

@end
