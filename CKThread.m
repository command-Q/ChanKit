/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKThread.h - Thread object. May be initialized from thread XML or preinitialized from page XML.
 */


#import "CKThread.h"

@implementation CKThread

- (id)init {
	if(self = [super init])
		posts = [[NSMutableArray alloc] init];
	return self;
}

- (id)initByReferencingURL:(NSURL*)url {
	if(self = [self init]) {
		URL = [[CKUtil URLByDeletingFragment:url] retain];
		board = [[CKUtil parseBoard:URL] retain];
		ID = [CKUtil parseThreadID:URL];
		initialized = NO;
		postcount = 0;
		
		DLog(@"URL: %@", URL);
		DLog(@"Board: %@", board);
		DLog(@"Thread ID: %d",ID);
		DLog(@"Thread URL: %@",URL);

		[posts addObject:[[CKPost alloc] initByReferencingURL:URL]];
	}
	return self;
}
+ (CKThread*)threadReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	return nil;
}
+ (CKThread*)threadFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (id)initWithPage:(DDXMLDocument*)doc {
	if(self = [self initByReferencingURL:[NSURL URLWithString:[doc URI]]]) {		
		DDXMLElement* root = [[[[doc copy] autorelease] nodesForXPath:[[CKRecipe sharedRecipe] lookup:@"Thread/Root"] error:NULL] objectAtIndex:0];
		[root setURI:[URL absoluteString]];
		NSArray* pre = [root nodesForXPath:
						[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Thread/Preceding"],[NSNumber numberWithInt:ID]] error:NULL];
		if([pre count])
			for(int i = [(DDXMLNode*)[pre objectAtIndex:0] index]; i >= 0; i--)
				[root removeChildAtIndex:i];
		NSArray* post = [root nodesForXPath:
						[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Thread/Following"],[NSNumber numberWithInt:ID]] error:NULL];
		if([post count])
			for(int i = [root childCount]-1; i >= [(DDXMLNode*)[post objectAtIndex:0] index]; i--)
				[root removeChildAtIndex:i];

		[[posts objectAtIndex:0] populate:root];

		NSArray* replies = [[[CKRecipe sharedRecipe] lookup:@"Thread/Trailing" inDocument:root] 
						componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

		for(NSString* reply in replies) {
			[doc setURI:[NSString stringWithFormat:@"%@#%@",URL,reply]];
			[posts addObject:[[CKPost alloc] initWithXML:doc threadContext:self]];
		}		

		
		postcount = [[[CKRecipe sharedRecipe] lookup:@"Thread/Omitted" inDocument:root] intValue] + [posts count];
		imagecount = [[[CKRecipe sharedRecipe] lookup:@"Thread/OmittedImages" inDocument:root] intValue] + [[self imagePosts] count];
		DLog(@"Posts: %d",postcount);
		DLog(@"Images: %d",imagecount);		
	}
	return self;
}
+ (CKThread*)threadFromPage:(DDXMLDocument*)doc { return [[[self alloc] initWithPage:doc] autorelease]; }

- (void)dealloc {
	[URL release];
	[board release];
	[posts release];
	[super dealloc];
}

- (int)populate { 
	int error;
	DDXMLDocument* doc;
	if((error = [CKUtil fetchXML:&doc fromURL:URL]))
		return error;
	[self populate:doc];
	return 0;
}

- (void)populate:(DDXMLDocument*)doc {
	NSArray* replies = [[[CKRecipe sharedRecipe] lookup:@"Thread/Replies" inDocument:doc] 
						componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	if(!initialized)
		for(CKPost* post in posts)
			[post populate:doc];
	else if(postcount > 1) {
		// Check if the structure of the thread has changed
		CKPost* last = [posts lastObject];
		int index = [[doc nodesForXPath:[[CKRecipe sharedRecipe] lookup:@"Post/Indexes"] error:NULL] indexOfObject:
					[[doc nodesForXPath:[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Post/Index"],last.IDString] error:NULL] 
					   objectAtIndex:0]]+1;
		if(last.index != index)	//Something was deleted. Find it.
			for(CKPost* post in posts)
				if(![[doc nodesForXPath:[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Post/Index"],post.IDString] error:NULL] count])
					post.deleted = YES;
		replies = [replies subarrayWithRange:NSMakeRange(index,[replies count]-index)];
		// Right now we avoid a deep check for changes to posts, such as ban messages being placed, simply due to the extra processing time required
	}
	initialized = YES;
	
	self.sticky = [[CKRecipe sharedRecipe] lookup:@"Thread/Sticky" inDocument:doc] != nil;
	self.closed = [[CKRecipe sharedRecipe] lookup:@"Thread/Closed" inDocument:doc] != nil;
	DLog(@"Sticky: %d",self.sticky);
	DLog(@"Closed: %d",self.closed);
	
	NSString* URI = [doc URI];
	for(NSString* reply in replies) {
		[doc setURI:[NSString stringWithFormat:@"%@#%@",URL,reply]];
		CKPost* post = [[CKPost alloc] initWithXML:doc threadContext:self];
		[posts insertObject:post atIndex:post.index];
	}
	[doc setURI:URI]; // A bit messy
	postcount = [posts count];
	imagecount = [[self imagePosts] count];
	DLog(@"Posts: %d",postcount);
	DLog(@"Images: %d",imagecount);
}

@synthesize URL;
@synthesize ID;
@synthesize board;
@synthesize posts;
@synthesize postcount;
@synthesize imagecount;
@synthesize initialized;

- (BOOL)sticky { return self.OP.sticky; }
- (BOOL)closed { return self.OP.closed; }
- (void)setSticky:(BOOL)stickiness { self.OP.sticky = stickiness; }
- (void)setClosed:(BOOL)locked { self.OP.closed = locked; }

- (CKPost*)OP { 
	if(!initialized)
		[self populate];
	return [posts objectAtIndex:0]; 
}
// Refresh the thread and return the most recent post
- (CKPost*)latest {
	[self populate];
	return [posts lastObject];
}
						  
- (CKPost*)postWithID:(int)idno {
	NSUInteger idx;
	if((idx = [posts indexOfObjectPassingTest:^(id post, NSUInteger idx, BOOL *stop){return *stop = [post ID] == idno;}]) != NSNotFound)
		return [posts objectAtIndex:idx];
	return nil;
}

- (BOOL)isBy:(CKUser*)author { return [[[posts objectAtIndex:0] user] isEqual:author]; }
- (NSArray*)postsBy:(CKUser*)author {
	return [posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.user = %@",author]];	
}
- (NSArray*)postsExcluding:(CKUser*)author { 
	return [posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.user != %@",author]]; 
}

- (NSArray*)postsQuoting:(CKPost*)post {
	return [posts objectsAtIndexes:[posts indexesOfObjectsPassingTest:^(id quoter, NSUInteger idx, BOOL *stop){return [quoter quoted:post];}]];
}

- (NSArray*)postsFromIndex:(int)idex {
	DLog(@"Getting posts from index: %d to length: %d",idex,[posts count] - idex);
	return [posts subarrayWithRange:NSMakeRange(idex, [posts count] - idex)];
}

- (NSArray*)imagePosts { return [posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"image != nil"]]; }
- (NSArray*)images {
	NSMutableArray* imgs = [NSMutableArray arrayWithCapacity:imagecount];
	for(CKPost* post in [posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"image != nil"]])
		[imgs addObject:post.image];
	return imgs;
}

- (NSString*)description {
	NSMutableString* desc = [NSMutableString stringWithFormat:@"%d posts and %d images",postcount,imagecount];
	for(CKPost* post in posts) 
		[desc appendFormat:@"\n"
		 "______________________________________________________________________________________________________________"
		 "\n%@",post];
	return desc;
}
- (BOOL)isEqual:(id)other { return [self hash] == [other hash]; }
- (NSUInteger)hash { return [[posts objectAtIndex:0] hash]; }



@end