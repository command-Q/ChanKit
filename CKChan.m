/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2009-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKChan.h - Top level object encapsulating an entire imageboard.
 *			   All other objects can be navigated to from here.
 */

#import "CKChan.h"


@implementation CKChan

- (id)init {
	if(self = [super init])
		boards = [[NSMutableArray alloc] init];
	return self;
}

- (id)initWithURL:(NSURL*)url {
	if(self = [self init]) {
		URL = [url retain];
		DLog(@"URL: %@",URL);

		NSXMLDocument* doc;
		if([CKUtil fetchXML:&doc fromURL:URL]) return nil;
		
		name = [[[CKRecipe sharedRecipe] lookup:@"Chan.Name" inDocument:doc] retain];
		DLog(@"Name: %@",name);
			
		slogan = [[[CKRecipe sharedRecipe] lookup:@"Chan.Slogan" inDocument:doc] retain];
		DLog(@"Slogan: %@",slogan);
	
		about = [[[CKRecipe sharedRecipe] lookup:@"Chan.About" inDocument:doc] retain];
		DLog(@"About: %@",about);
		
		// Safe to assume that all imageboards have at least one stylesheet?
		NSURL* css = [NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Chan.Stylesheet" inDocument:doc]];
		NSString* logourl = [NSString stringWithFormat:@"%@://%@%@",[css scheme],[css host],
							 [[NSString stringWithContentsOfURL:css encoding:NSUTF8StringEncoding error:NULL]
							  stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Chan.Logo"] capture:1L]];
		if(logourl) {
			DLog(@"Logo URL: %@",logourl);
			logo = [[CKImage alloc] initByReferencingURL:[NSURL URLWithString:logourl]];
			DLog(@"Logo:\n%@",logo);
		}
		
		categories = [[[[CKRecipe sharedRecipe] lookup:@"Chan.Categories" inDocument:doc] 
					  componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] retain];
		DLog(@"Categories: \n%@",categories);
		
		NSMutableArray* linkurls = [[[[[CKRecipe sharedRecipe] lookup:@"Chan.Links.URLs" inDocument:doc] 
									 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] mutableCopy] autorelease];
		for(int i = 0; i < [linkurls count]; i++)
			[linkurls replaceObjectAtIndex:i withObject:[URL URLByAppendingPathComponent:[linkurls objectAtIndex:i]]];
		links = [[NSDictionary alloc] initWithObjects:linkurls 
											  forKeys:[[[CKRecipe sharedRecipe] lookup:@"Chan.Links.Keys" inDocument:doc] 
													   componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
		DLog(@"Links: %@",links);
		
		for(NSString* board in [[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.URL" inDocument:doc] 
								componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]])
			[boards addObject:[[[CKBoard alloc] initByReferencingURL:[NSURL URLWithString:board]
															  title:[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.Title"
																						 inDocument:doc 
																							   test:board]
														   category:[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.Category"
																						 inDocument:doc 
																							   test:board]
														   is18plus:[[CKRecipe sharedRecipe] lookup:@"Chan.Boards.Age" 
																						 inDocument:doc 
																							   test:board] != nil] autorelease]];
		DLog(@"# of Boards: %d",[boards count]);
	}
	return self;
}
+ (CKChan*)chanFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

// sitename must be part of the supported sites array of a recipe
- (id)initWithName:(NSString*)sitename {
	NSURL* url;
	if((url = [[CKRecipe sharedRecipe] URLForSite:sitename]))
		return [self initWithURL:url];
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
	NSUInteger index;
	if((index = [boards indexOfObjectPassingTest:^(id board, NSUInteger idx, BOOL *stop) { return *stop = [[board name] isEqualToString:nm]; }])
			!= NSNotFound) {
		[[boards objectAtIndex:index] populate];
		return [boards objectAtIndex:index];		
	}
	return nil;
}
@end
