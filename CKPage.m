/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKPage.m - A single page.
 */

#import "CKPost.h"
#import "CKThread.h"
#import "CKPage.h"

@implementation CKPage

- (id)init {
	if((self = [super init]))
		threads = [[NSMutableArray alloc] init];
	return self;
}

- (BOOL)parseURL:(NSURL*)url {
	if(url && url != URL && ![[url absoluteURL] isEqual:[URL absoluteURL]]) {
		[URL release];
		[board release];
		URL = [url retain];
		board = [[CKUtil parseBoard:URL] retain];
		index = [CKUtil parsePage:URL];
		DLog(@"URL: %@", URL);
		DLog(@"Board: %@", board);
		DLog(@"Index: %d",index);		
	}
	return url != nil;
}

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [self init]) && [self parseURL:url])
		return self;
	[self release];
	return nil;
}
+ (CKPage*)pageReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	[self release];
	return nil;
}
+ (CKPage*)pageFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (id)initWithXML:(NSXMLDocument*)doc {
	if((self = [self initByReferencingURL:[NSURL URLWithString:[doc URI]]]))
		[self populate:doc];
	return self;
}
+ (CKPage*)pageFromXML:(NSXMLDocument*)doc { return [[[self alloc] initWithXML:doc] autorelease]; }

- (void)dealloc {
	[URL release];
	[board release];
	[threads release];
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
	index = [[[CKRecipe sharedRecipe] lookup:@"Page.Number" inDocument:doc] integerValue];
	DLog(@"Index: %d",index);
	[threads removeAllObjects];
	NSString* URI = [doc URI];
	for(NSString* href in [[[CKRecipe sharedRecipe] lookup:@"Page.Threads" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		[doc setURI:[[NSURL URLWithString:href relativeToURL:URL] absoluteString]];
		CKThread* thread = [[CKThread alloc] initWithPage:doc];
		if(thread) {
			[threads addObject:thread];
			[thread release];
		}		
	}
	[doc setURI:URI];
	DLog(@"Threads: %d",[threads count]);
}

@synthesize URL;
@synthesize board;
@synthesize index;
@synthesize threads;

- (CKThread*)getThread:(int)idx {
	if(idx >= [threads count]) return nil;
	if(![[threads objectAtIndex:idx] initialized])
		[[threads objectAtIndex:idx] populate];
	return [threads objectAtIndex:idx];
}

- (CKPost*)newestPost {
	CKPost* result = nil;
	CKPost* candidate;
	for(CKThread* thread in threads)
		if((candidate = [[thread posts] lastObject]).ID > result.ID)
			result = candidate;
	return result;
}
- (CKPost*)oldestPost {
	CKPost* result = [[[threads objectAtIndex:0] posts] objectAtIndex:0];
	CKPost* candidate;
	for(int i = 1; i < [threads count]; i++)
		if((candidate = [[[threads objectAtIndex:i] posts] objectAtIndex:0]).ID < result.ID)
			result = candidate;
	return result;	
}
- (NSTimeInterval)rangeOfPosts { return [[[self newestPost] date] timeIntervalSinceDate:[[self oldestPost] date]]; }

- (NSString*)prettyPrint {
	NSMutableString* print = [NSMutableString string];
	for(CKThread* t in threads) {
		int disp = fmin([t.posts count] - 5,1);
		[print appendFormat:@"\n\e[4m\t%122s\e[0m\n%@\n\e[4m\t%122s\e[0m\n\t| %d posts and %d images",
		   "",[[t.posts objectAtIndex:0] prettyPrint],"",t.postcount,t.imagecount];
		for(CKPost* p in [[t posts] subarrayWithRange:NSMakeRange(disp,[t.posts count] - disp)])
			[print appendFormat:@"\n\t|\e[4m%120s\e[0m\n\t| %@","",
			   [[[p prettyPrint] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@"\n\t| "]];
	}
	return [print stringByAppendingFormat:@"\n\t|\e[4m%120s\e[0m\n",""];
}

@end
