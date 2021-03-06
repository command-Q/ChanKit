/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKBoard.h - Board object. May be initialized from any page on the board.
 */

@class CKPost;
@class CKPage;

@interface CKBoard : NSObject {
	NSURL* URL;
	NSURL* boardroot;
	NSString* name;
	NSString* title;
	NSString* alternatetitle;
	NSString* category;
	NSArray* rules;
	NSMutableArray* pages;
	int numpages;
	BOOL is18plus;
}

@property(nonatomic,readonly) NSURL* URL;
@property(nonatomic,readonly) NSString* name;
@property(nonatomic,readonly) NSString* title;
@property(nonatomic,readonly) NSString* alternatetitle;
@property(nonatomic,readonly) NSString* category;
@property(nonatomic,readonly) NSArray* rules;
@property(nonatomic,readonly) NSArray* pages;
@property(nonatomic,readonly) int numpages;
@property(nonatomic,readonly) BOOL is18plus;

- (id)initByReferencingURL:(NSURL*)url;
+ (CKBoard*)boardReferencingURL:(NSURL*)url;
- (id)initByReferencingURL:(NSURL*)url title:(NSString*)atitle category:(NSString*)cat is18plus:(BOOL)NSFW;
+ (CKBoard*)boardReferencingURL:(NSURL*)url title:(NSString*)atitle category:(NSString*)cat is18plus:(BOOL)NSFW;
- (id)initWithURL:(NSURL*)url;
+ (CKBoard*)boardFromURL:(NSURL*)url;
- (void)dealloc;
- (int)populate;

- (void)setCategory:(NSString*)cat is18Plus:(BOOL)nsfw;
- (CKPage*)getPage:(int)no;
- (NSArray*)fetchAllPages;
- (CKPost*)newestPost;
- (int)newestPostID;
- (CKPost*)findPostForImage:(NSURL*)url;
- (NSString*)description;

@end
