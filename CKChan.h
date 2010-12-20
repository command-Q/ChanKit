/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKChan.h - Top level object encapsulating an entire imageboard.
 *			   All other objects can be navigated to from here.
 */

#import "CKBoard.h"

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
@property(nonatomic,readonly,copy) NSURL* URL;
@property(nonatomic,readonly,copy) NSString* name;
@property(nonatomic,readonly,copy) NSString* about;
@property(nonatomic,readonly,copy) NSString* slogan;
@property(nonatomic,readonly,copy) CKImage* logo;
@property(nonatomic,readonly,copy) NSDictionary* links;
@property(nonatomic,readonly,copy) NSArray* categories;
@property(nonatomic,readonly,copy) NSArray* boards;

- (id)initWithURL:(NSURL*)url;
+ (CKChan*)chanFromURL:(NSURL*)url;
- (id)initWithName:(NSString*)sitename;
+ (CKChan*)chanNamed:(NSString*)sitename;
- (void)dealloc;

- (NSArray*)workSafeBoards;
- (NSArray*)boardsInCategory:(NSString*)category;
- (CKBoard*)boardNamed:(NSString*)nm;
@end
