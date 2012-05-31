/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKChan.h - Top level object encapsulating an entire imageboard. All other objects can be navigated to from here.
 */

@class CKImage;
@class CKBoard;

@interface CKChan : NSObject {
	NSURL* URL;
	NSString* name;
	NSString* about;
	NSString* slogan;
	CKImage* logo;
	NSDictionary* links;
	NSArray* categories;
	NSMutableArray* boards;
}

@property(nonatomic,readonly) NSURL* URL;
@property(nonatomic,readonly) NSString* name;
@property(nonatomic,readonly) NSString* about;
@property(nonatomic,readonly) NSString* slogan;
@property(nonatomic,readonly) CKImage* logo;
@property(nonatomic,readonly) NSDictionary* links;
@property(nonatomic,readonly) NSArray* categories;
@property(nonatomic,readonly) NSArray* boards;

- (id)initByReferencingURL:(NSURL*)url;
+ (CKChan*)chanReferencingURL:(NSURL*)url;
- (id)initWithURL:(NSURL*)url;
+ (CKChan*)chanFromURL:(NSURL*)url;
- (id)initWithName:(NSString*)sitename;
+ (CKChan*)chanNamed:(NSString*)sitename;
- (void)dealloc;
- (int)populate;

- (NSArray*)workSafeBoards;
- (NSArray*)boardsInCategory:(NSString*)category;
- (CKBoard*)boardNamed:(NSString*)nm;

@end
