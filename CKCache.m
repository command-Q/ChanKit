/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKCache.m - This implements a shared browsing cache from which previously allocated objects can be requested.
 */

#import "CKCache.h"

@implementation CKCache

static CKCache* sharedInstance = nil;

+ (CKCache*)sharedCache {
	@synchronized(self) {
		if(!sharedInstance)
			[[self alloc] init];		
	}
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
	@synchronized(self) {
		if(!sharedInstance) {
			sharedInstance = [super allocWithZone:zone];
			return sharedInstance;
		}
	}
	return nil;
}

- (id)copyWithZone:(NSZone *)zone { return self; }
- (id)retain { return self; }
- (void)release {}
- (id)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }

- (id)init {
    @synchronized([self class]) {
        if (!sharedInstance)
            if((sharedInstance = self = [super init]))
				posts = [[NSMutableSet alloc] init];
    }
    return sharedInstance;
}

@synthesize posts;
/*
- (CKPost*)postForIdentifier:(NSUInteger)ID {
	@synchronized(self) {
		return nil;
	}
}
 */
@end
