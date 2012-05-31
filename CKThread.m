/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKThread.m - Thread object. May be initialized from thread XML or preinitialized from page XML.
 */


#import "CKThread.h"
#import "CKPost.h"
#import "CKUser.h"
#import "CKPost_priv.h"

@interface CKThread()
@property(nonatomic,readwrite) BOOL sticky;
@property(nonatomic,readwrite) BOOL closed;
@end

@implementation CKThread

- (id)init {
	if((self = [super init]))
		posts = [[NSMutableArray alloc] init];
	return self;
}

- (BOOL)parseURL:(NSURL*)url {
	if(url && url != URL && ![[url absoluteURL] isEqual:[URL absoluteURL]]) {
		[URL release];
		[board release];
		[posts removeAllObjects];
		postcount = imagecount = 0;

		URL = [[CKUtil URLByDeletingFragment:url] retain];
		board = [[CKUtil parseBoard:URL] retain];
		ID = [CKUtil parseThreadID:URL];
		initialized = NO;

		DLog(@"URL: %@", URL);
		DLog(@"Board: %@", board);
		DLog(@"Thread ID: %d",ID);
		DLog(@"Thread URL: %@",URL);
		
		CKPost* OP = [CKPost postReferencingURL:URL];
		if(OP)
			[posts addObject:OP];
		return board && ID >= 0 && OP;
	}
	return url != nil;
}

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [self init]) && [self parseURL:url])
		return self;
	[self release];
	return nil;
}
+ (CKThread*)threadReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	[self release];
	return nil;
}
+ (CKThread*)threadFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (id)initWithPage:(NSXMLDocument*)doc {
	if((self = [self initByReferencingURL:[NSURL URLWithString:[doc URI]]])) {
		NSXMLElement* root = [[[[doc copy] autorelease] nodesForXPath:[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Thread.Root"],self.IDString]
		                                                        error:NULL] objectAtIndex:0];
		[[root rootDocument] setURI:[URL absoluteString]];
		NSString* cleanup;
		if((cleanup = [[CKRecipe sharedRecipe] lookup:@"Thread.Preceding"])) {
			NSArray* pre = [root nodesForXPath:[NSString stringWithFormat:cleanup,[NSNumber numberWithInt:ID]] error:NULL];
			if([pre count])
				for(int i = [(NSXMLNode*)[pre objectAtIndex:0] index]; i >= 0; i--)
					[root removeChildAtIndex:i];
		}
		if((cleanup = [[CKRecipe sharedRecipe] lookup:@"Thread.Following"])) {
			NSArray* post = [root nodesForXPath:[NSString stringWithFormat:cleanup,[NSNumber numberWithInt:ID]] error:NULL];
			if([post count])
				for(int i = [root childCount]-1; i >= [(NSXMLNode*)[post objectAtIndex:0] index]; i--)
					[root removeChildAtIndex:i];
		}
		[(CKPost*)[posts objectAtIndex:0] populate:root threadContext:nil];

		NSArray* replies = [[[CKRecipe sharedRecipe] lookup:@"Thread.Trailing" inDocument:root] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];

		postcount = [[[CKRecipe sharedRecipe] lookup:@"Thread.Omitted" inDocument:root] intValue];
		NSString* URI = [doc URI];
		for(NSString* reply in replies) {
			[doc setURI:[NSString stringWithFormat:@"%@#%@",URL,reply]];
			CKPost* post = [[CKPost alloc] initWithXML:doc threadContext:self];
			post.index = ++postcount;
			if(post) {
				[posts addObject:post];
				[post release];
			}
		}
		++postcount;
		[doc setURI:URI];

		imagecount = [[[CKRecipe sharedRecipe] lookup:@"Thread.OmittedImages" inDocument:root] intValue] + [[self imagePosts] count];
		DLog(@"Posts: %d",postcount);
		DLog(@"Images: %d",imagecount);		
	}
	return self;
}
+ (CKThread*)threadFromPage:(NSXMLDocument*)doc { return [[[self alloc] initWithPage:doc] autorelease]; }

- (void)dealloc {
	[URL release];
	[board release];
	[posts release];
	[super dealloc];
}

- (int)populate {
	NSXMLDocument* doc;
	int error = [CKUtil fetchXML:&doc fromURL:URL];
	if(error != CK_ERR_SUCCESS)
		return error;
	if(![self parseURL:[NSURL URLWithString:[doc URI]]])
		return CK_ERR_REDIRECT;
	[self populate:doc];
	return CK_ERR_SUCCESS;
}

- (void)populate:(NSXMLDocument*)doc {
	NSArray* replies = [[[CKRecipe sharedRecipe] lookup:@"Thread.Replies" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	__block NSUInteger deleted = [[posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.deleted = YES"]] count];
	if(!initialized) {
		for(CKPost* post in [posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"OP = YES || abbreviated = YES"]])
			[post populate:doc threadContext:self];
		// This would work just as well for repopulating a thread and look nicer, but it's terribly less efficient
		replies = [replies objectsAtIndexes:[replies indexesOfObjectsPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
			return (BOOL)![self postWithID:[obj integerValue]];
		}]];
	}
	else if(postcount > 1) {
		// Check if the structure of the thread has changed
		// Right now we avoid a deep check for changes to posts, such as ban messages being placed, simply due to the extra processing time required
		// The old method was quite broken. This one isn't very pretty, but it's efficient.
		__block NSUInteger lastcommon = 0, deletedsince = deleted;
		[posts enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			if(!idx) return;
			if([obj deleted]) deletedsince--;
			else {
				NSUInteger index = [replies indexOfObject:[obj IDString]];
				if(index == NSNotFound) {
					[obj setDeleted:YES];
					deleted++;
				}
				else {
					if(!lastcommon) lastcommon = index + 1;
					*stop = index == idx - deletedsince - 1;
				}
			}
		}];
		replies = [replies subarrayWithRange:NSMakeRange(lastcommon,[replies count]-lastcommon)];
	}
	initialized = YES;
	self.sticky = [[CKRecipe sharedRecipe] lookup:@"Thread.Sticky" inDocument:doc] != nil;
	self.closed = [[CKRecipe sharedRecipe] lookup:@"Thread.Closed" inDocument:doc] != nil;
	DLog(@"Sticky: %d",self.sticky);
	DLog(@"Closed: %d",self.closed);

	NSString* URI = [doc URI];
	for(NSString* reply in replies) {
		NSAutoreleasePool* loop = [[NSAutoreleasePool alloc] init];
		[doc setURI:[NSString stringWithFormat:@"%@#%@",URL,reply]];
		CKPost* post = [[CKPost alloc] initWithXML:doc threadContext:self];
		if(post) {
			[posts insertObject:post atIndex:post.index+deleted];
			[post release];
		}
		[loop drain];
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

- (NSString*)IDString { return [NSString stringWithFormat:@"%d",ID]; }

- (CKPost*)OP { 
	if(!initialized)
		[self populate];
	return [posts objectAtIndex:0]; 
}

- (NSArray*)replies {
	if(!initialized)
		[self populate];
	return [posts subarrayWithRange:NSMakeRange(1,[posts count]-2)];
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
	if(idex >= [posts count]) return nil;
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
	NSString* delim = @"\n______________________________________________________________________________________________________________\n";
	NSMutableString* desc = [NSMutableString stringWithFormat:@"%d posts and %d images",postcount,imagecount];
	for(CKPost* post in posts)
		[desc appendFormat:@"%@%@",delim,post];
	return [desc stringByAppendingString:delim];
}
- (NSString*)prettyPrint {
	NSMutableString* desc = [NSMutableString stringWithFormat:@"%d posts and %d images",postcount,imagecount];
	for(CKPost* post in posts)
		[desc appendFormat:@"\n\e[4m%110s\e[0m\n%@","",[post prettyPrint]];
	return [desc stringByAppendingFormat:@"\n\e[4m%110s\e[0m\n",""];
}
- (BOOL)isEqual:(id)other { return [self hash] == [other hash]; }
- (NSUInteger)hash { return [[posts objectAtIndex:0] hash]; }

@end