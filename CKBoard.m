/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKBoard.m - Board object. May be initialized from any page on the board.
 */

#import "CKImage.h"
#import "CKPost.h"
#import "CKThread.h"
#import "CKPage.h"
#import "CKBoard.h"

@implementation CKBoard

- (id)init {
	if((self = [super init]))
		pages = [[NSMutableArray alloc] init];
	return self;
}

- (BOOL)parseURL:(NSURL*)url {
	if(url && url != URL && ![[url absoluteURL] isEqual:[URL absoluteURL]]) {
		[URL release];
		[name release];
		[boardroot release];
		URL = [url retain];
		name = [[CKUtil parseBoard:URL] retain];
		boardroot = [[CKUtil parseBoardRoot:URL] retain];
		DLog(@"URL: %@", URL);
		DLog(@"Board: %@", name);		
		DLog(@"Board Root: %@", boardroot);		
	}
	return url != nil;
}

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [self init]) && [self parseURL:url])
		return self;
	[self release];
	return nil;
}
+ (CKBoard*)boardReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initByReferencingURL:(NSURL*)url title:(NSString*)atitle category:(NSString*)cat is18plus:(BOOL)NSFW{
	if((self = [self initByReferencingURL:url])) {
		title = [atitle retain];
		DLog(@"Title: %@", title);
		[self setCategory:cat is18Plus:NSFW];		
	}
	return self;
}
+ (CKBoard*)boardReferencingURL:(NSURL*)url title:(NSString*)atitle category:(NSString*)cat is18plus:(BOOL)NSFW {
	return [[[self alloc] initByReferencingURL:url title:atitle category:cat is18plus:NSFW] autorelease];
}

- (id)initWithURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	[self release];
	return nil;
}
+ (CKBoard*)boardFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (void)dealloc {
	[URL release];
	[boardroot release];
	[name release];
	[title release];
	[alternatetitle release];
	[category release];
	[rules release];
	[pages release];
	[super dealloc];
}

- (int)populate {
	NSXMLDocument* doc;
	int error = [CKUtil fetchXML:&doc fromURL:URL];
	if(error != CK_ERR_SUCCESS)
		return error;
	if(![self parseURL:[NSURL URLWithString:[doc URI]]])
		return CK_ERR_REDIRECT;
		
	int index  = [[[CKRecipe sharedRecipe] lookup:@"Page.Number" inDocument:doc] integerValue];	
	if(!title) {
		title = [[[CKRecipe sharedRecipe] lookup:@"Board.Title" inDocument:doc test:name] retain];
		DLog(@"Title: %@",title);
	}
	alternatetitle = [[[CKRecipe sharedRecipe] lookup:@"Board.AlternateTitle" inDocument:doc] retain];
	DLog(@"Alt Title: %@",alternatetitle);	

	rules = [[[[CKRecipe sharedRecipe] lookup:@"Board.Rules" inDocument:doc]
	           componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] retain];
	DLog(@"Rules: %@",rules);
	
	[pages removeAllObjects];
	CKPage* page;
	for(NSString* pageno in [[[CKRecipe sharedRecipe] lookup:@"Board.Pages" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
		if((page = [CKPage pageReferencingURL:[boardroot URLByAppendingPathComponent:pageno]]))
			[pages addObject:page];
	if((page = [CKPage pageFromXML:doc]))
		[pages insertObject:page atIndex:index];
	 
	numpages = [pages count];
	DLog(@"Pages: %d",numpages);

	return CK_ERR_SUCCESS;
}

@synthesize URL;
@synthesize name;
@synthesize title;
@synthesize alternatetitle;
@synthesize category;
@synthesize rules;
@synthesize pages;
@synthesize numpages;
@synthesize is18plus;

- (void)setCategory:(NSString*)cat is18Plus:(BOOL)nsfw {
	if(cat != category) {
		[category release];
		category = [cat copy];
	}
	DLog(@"Category: %@",category);
	is18plus = nsfw;
	DLog(@"18+: %d",is18plus);
}

- (CKPage*)getPage:(int)no {
	if(![pages count]) //Not initialized!
		[self populate];
	if(no >= numpages) return nil;
	CKPage* pg = [pages objectAtIndex:no];
	if(![[pg threads] count])
		[pg populate];
	return pg;
}

- (NSArray*)fetchAllPages {
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	[queue setSuspended:YES];
	for(CKPage* page in pages)
		[queue addOperationWithBlock:^{
			[page populate];
		}];
	[queue setSuspended:NO];
    [queue waitUntilAllOperationsAreFinished];
	[queue release];
	return self.pages;
}

- (CKPost*)findPostForImage:(NSURL*)url {
	CKImage* img = [CKImage imageReferencingURL:url];	
//	__block NSMutableSet* searched = [NSMutableSet set];
	__block CKPost* result = nil;
	// This is an ungodly trainwreck (though it works)
	NSLock* lock = [[NSLock alloc] init];
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
	[queue setSuspended:YES];

	for(CKPage* page in pages)
		[queue addOperationWithBlock:^{
			BOOL done;

			[lock lock];
			done = result != nil;
			[lock unlock];
			if(done) return;
			
			[page populate];

			[lock lock];
			done = result != nil;
			[lock unlock];
			if(done) return;

			CKPost* current = [page newestPost];
			if([current image] && [current.image.URL isEqualTo:url]) {
				[lock lock];
				result = current;
				[lock unlock];
				return;
			}
			NSComparisonResult newest = [[current date] compare:[img timestamp]];
			current = [page oldestPost];
			if([current image] && [current.image.URL isEqualTo:url]) {
				[lock lock];
				result = current;
				[lock unlock];
				return;
			}
			NSComparisonResult oldest = [[current date] compare:[img timestamp]];
			if(newest != NSOrderedAscending && oldest != NSOrderedDescending) {
				// Image may be on this page
				for(CKThread* thread in [page threads]) {
					[lock lock];
					done = result != nil;
					[lock unlock];
					if(done) return;
					//if([searched containsObject:thread]) continue;
					current = [[thread posts] lastObject];
					if([current image] && [current.image.URL isEqualTo:url]) {
						[lock lock];
						result = current;
						[lock unlock];
						return;
					}
					newest = [[current date] compare:[img timestamp]];
					current = [[thread posts] objectAtIndex:0];
					if([current image] && [current.image.URL isEqualTo:url]) {
						[lock lock];
						result = current;
						[lock unlock];
						return;
					}						
					oldest = [[current date] compare:[img timestamp]];
					if(newest != NSOrderedAscending && oldest != NSOrderedDescending) {
						// Image may be in this thread
						[lock lock];
						done = result != nil;
						[lock unlock];
						if(done) return;
						[thread populate];
						[lock lock];
						done = result != nil;
						[lock unlock];
						if(done) return;
						NSArray* candidates = [thread imagePosts];
						NSUInteger idx = [candidates indexOfObjectPassingTest:^(id post, NSUInteger idx, BOOL *stop) {
							return *stop = [[[(CKPost*)post image] URL] isEqualTo:url];
						}];
						if(idx != NSNotFound) {
							[lock lock];
							result = [candidates objectAtIndex:idx];
							[lock unlock];
							return;
						}
					}
					//[searched addObject:thread];
				}
			}
		}];
	
	[queue setSuspended:NO];
    [queue waitUntilAllOperationsAreFinished];
	[lock release];
	[queue release];
	return result;
}

/** Single-threaded version, slow
- (CKPost*)findPostForImage:(NSURL*)url {
	[self fetchAllPages];
	CKImage* img = [CKImage imageReferencingURL:url];
	NSMutableSet* searched = [NSMutableSet set];
	for(CKPage* page in pages) {
		// Have to check for this first
		CKPost* current = [page newestPost];
		if([current image] && [current.image.URL isEqualTo:url]) return current;
		NSComparisonResult newest = [[current date] compare:[img timestamp]];
		current = [page oldestPost];
		if([current image] && [current.image.URL isEqualTo:url]) return current;
		NSComparisonResult oldest = [[current date] compare:[img timestamp]];
		if(newest != NSOrderedAscending && oldest != NSOrderedDescending) {
			// Image may be on this page
			for(CKThread* thread in [page threads]) {
				if([searched containsObject:thread]) continue;
				current = [[thread posts] lastObject];
				if([current image] && [current.image.URL isEqualTo:url]) return current;
				newest = [[current date] compare:[img timestamp]];
				current = [[thread posts] objectAtIndex:0];
				if([current image] && [current.image.URL isEqualTo:url]) return current;
				oldest = [[current date] compare:[img timestamp]];
				if(newest != NSOrderedAscending && oldest != NSOrderedDescending) {
					// Image may be in this thread
					[thread populate];
					NSArray* candidates = [thread imagePosts];
					NSUInteger idx;
					if((idx = [candidates indexOfObjectPassingTest:^(id post, NSUInteger idx, BOOL *stop) {
						return *stop = [[[(CKPost*)post image] URL] isEqualTo:url];
					}]) != NSNotFound)
						return [candidates objectAtIndex:idx];
				}
				[searched addObject:thread];
			}
		}
	}
	return nil;
}
*/
- (CKPost*)newestPost { return [[pages objectAtIndex:0] newestPost]; }

- (int)newestPostID {
	NSXMLDocument* doc;
	if([CKUtil fetchXML:&doc fromURL:boardroot] != CK_ERR_SUCCESS)
		return -1;
	
	int candidate, last = 0;
	for(NSString* idstr in [[[CKRecipe sharedRecipe] lookup:@"Page.IDs" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
		if((candidate = [idstr intValue]) > last)
			last = candidate;
	return last;
}

- (NSString*)description {
	return [NSString stringWithFormat:@"Board: %@\n\t\tTitle: %@\n\t\tCategory: %@\t\tAge: %@",name,title,category,is18plus?@"18+":@"All"];
}

@end
