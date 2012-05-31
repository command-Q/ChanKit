/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKChan.h - Top level object encapsulating an entire imageboard.
 *	All other objects can be navigated to from here.
 */

#import "CKImage.h"
#import "CKBoard.h"
#import "CKChan.h"

@implementation CKChan

- (id)init {
	if((self = [super init]))
		boards = [[NSMutableArray alloc] init];
	return self;
}

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [self init])) {
		URL = [url retain];
		DLog(@"URL: %@",URL);
	}
	return self;
}
+ (CKChan*)chanReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	[self release];
	return nil;
}
+ (CKChan*)chanFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

// sitename must be part of the supported sites array of a recipe
- (id)initWithName:(NSString*)sitename {
	NSURL* url;
	if((url = [[CKRecipe sharedRecipe] URLForSite:sitename]))
		return [self initWithURL:url];
	[self release];
	return nil;
}
+ (CKChan*)chanNamed:(NSString*)sitename { return [[[self alloc] initWithName:sitename] autorelease]; }

- (void)dealloc {
	[URL release];
	[name release];
	[about release];
	[slogan release];
	[logo release];
	[links release];
	[categories release];
	[boards release];
	[super dealloc];
}

- (int)populate {
	NSXMLDocument* doc;
	int error = [CKUtil fetchXML:&doc fromURL:URL];
	if(error != CK_ERR_SUCCESS)
		return error;
	NSURL* docURL = [[NSURL alloc] initWithString:[doc URI]];
	if(!docURL) return CK_ERR_REDIRECT;
	if(![[docURL absoluteURL] isEqual:[URL absoluteURL]]) {
		[URL release];
		URL = docURL;
	}
	else [docURL release];
	
	name = [[[CKRecipe sharedRecipe] lookup:@"Chan.Name" inDocument:doc] retain];
	DLog(@"Name: %@",name);
		
	slogan = [[[CKRecipe sharedRecipe] lookup:@"Chan.Slogan" inDocument:doc] retain];
	DLog(@"Slogan: %@",slogan);

	about = [[[CKRecipe sharedRecipe] lookup:@"Chan.About" inDocument:doc] retain];
	DLog(@"About: %@",about);
	
	NSString* csshref = [[CKRecipe sharedRecipe] lookup:@"Chan.Stylesheet" inDocument:doc];
	if(csshref) {
		ASIHTTPRequest* fetch = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:csshref relativeToURL:URL]];
		[CKUtil setProxy:[[NSUserDefaults standardUserDefaults] URLForKey:@"CKProxySetting"] onRequest:fetch];
		[fetch startSynchronous];
		if([CKUtil validateResponse:fetch] == CK_ERR_SUCCESS) {
			NSString* logohref = [[fetch responseString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Chan.Logo"] capture:1L];
			if(logohref)
				logo = [[CKImage alloc] initByReferencingURL:[NSURL URLWithString:logohref relativeToURL:URL]];
		}
	}
	
	categories = [[[[CKRecipe sharedRecipe] lookup:@"Chan.Categories" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] retain];
	DLog(@"Categories: \n%@",categories);
	
	NSMutableArray* linkurls = [[[[CKRecipe sharedRecipe] lookup:@"Chan.Links.URLs" inDocument:doc] 
	                              componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy];
	for(int i = 0; i < [linkurls count]; i++)
		[linkurls replaceObjectAtIndex:i withObject:[URL URLByAppendingPathComponent:[linkurls objectAtIndex:i]]];
	links = [[NSDictionary alloc] initWithObjects:linkurls forKeys:[[[CKRecipe sharedRecipe] lookup:@"Chan.Links.Keys" inDocument:doc] 
	                                                                  componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
	[linkurls release];
	DLog(@"Links: %@",links);
	
	for(NSString* boardlink in [[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.URL" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		CKBoard* board = [[CKBoard alloc] initByReferencingURL:[NSURL URLWithString:boardlink relativeToURL:URL]
		                                                 title:[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.Title"    inDocument:doc test:boardlink]
			                                          category:[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.Category" inDocument:doc test:boardlink]
			                                          is18plus:[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.Age"      inDocument:doc test:boardlink] != nil];
		if(board) {
			[boards addObject:board];
			[board release];
		}
	}
	DLog(@"# of Boards: %lu",(unsigned long)[boards count]);
	
	return CK_ERR_SUCCESS;
}

@synthesize URL;
@synthesize name;
@synthesize about;
@synthesize slogan;
@synthesize logo;
@synthesize links;
@synthesize categories;
@synthesize boards;

- (NSArray*)workSafeBoards {
	return [boards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.is18plus = NO"]]; 
}

- (NSArray*)boardsInCategory:(NSString*)category {
	return [boards filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF.category = %@",category]]; 
}

- (CKBoard*)boardNamed:(NSString*)nm {
	NSUInteger index = [boards indexOfObjectPassingTest:^(id board, NSUInteger idx, BOOL *stop) {
		return *stop = [[board name] isEqualToString:nm];
	}];
	if(index != NSNotFound) {
		[[boards objectAtIndex:index] populate];
		return [boards objectAtIndex:index];		
	}
	return nil;
}
@end
