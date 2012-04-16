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

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [self init])) {
		URL = [url retain];
		board = [[CKUtil parseBoard:URL] retain];
		index = [CKUtil parsePage:URL];
		DLog(@"URL: %@", URL);
		DLog(@"Board: %@", board);
		DLog(@"Index: %d",index);
	}
	return self;
}
+ (CKPage*)pageReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
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
	int error;
	NSXMLDocument* doc;
	if((error = [CKUtil fetchXML:&doc fromURL:URL]))
		return error;
	[self populate:doc];
	return 0;
}

- (void)populate:(NSXMLDocument*)doc {
	index = [[[CKRecipe sharedRecipe] lookup:@"Page.Number" inDocument:doc] integerValue];
	DLog(@"Index: %d",index);
	[threads removeAllObjects];
	NSString* URI = [doc URI];
	for(NSString* href in [[[CKRecipe sharedRecipe] lookup:@"Page.Threads" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		[doc setURI:[[NSURL URLWithString:href relativeToURL:URL] absoluteString]];		
		[threads addObject:[[[CKThread alloc] initWithPage:doc] autorelease]];		
	}
	[doc setURI:URI];
	DLog(@"Threads: %d",[threads count]);
}

@synthesize URL;
@synthesize board;
@synthesize index;
@synthesize threads;

- (CKThread*)getThread:(int)idx {
	if(idx > [threads count]) return nil;
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
	NSString* opdelim = @"\e[4m\t                                                                                                                         \e[0m\n";
	NSString* replydelim = @"\n\t|\e[4m                                                                                                                        \e[0m\n";
	NSMutableString* print = [NSMutableString string];
	for(CKThread* t in threads) {
		int disp = fmin([t.posts count] - 5,1);
		[print appendFormat:@"\n%@%@\n%@\t| %d posts and %d images",
		 opdelim,[[t.posts objectAtIndex:0] prettyPrint],opdelim,t.postcount,t.imagecount];
		for(CKPost* p in [[t posts] subarrayWithRange:NSMakeRange(disp,[t.posts count] - disp)])
			[print appendFormat:@"%@\t| %@",replydelim,
			 [[[p prettyPrint] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]
			  componentsJoinedByString:@"\n\t| "]];
	}
	return [print stringByAppendingString:replydelim];
}

@end
