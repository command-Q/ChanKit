/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKCache.h - This implements a shared browsing cache from which previously allocated objects can be requested.
 */

#import <Cocoa/Cocoa.h>

@class CKChan;

@interface CKCache : NSObject {
	NSMutableSet* posts;
}
@property(nonatomic,readonly,copy) NSSet* posts;

@end
