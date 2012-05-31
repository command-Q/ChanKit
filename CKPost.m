/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKPost.m - Data from a single post. Core building block of the framework.
 */

#import "CKUser.h"
#import "CKImage.h"
#import "CKPost.h"
#import "CKPost_priv.h"
#import "CKThread.h"

@implementation CKPost

// Object methods
- (id)init {
	if((self = [super init])) {
		quotes.values = [[NSMutableArray alloc] init];
		quotes.ranges = [[NSMutableArray alloc] init];
		adminmessages.values = [[NSMutableArray alloc] init];
		adminmessages.ranges = [[NSMutableArray alloc] init];
		inlinequotes.values = [[NSMutableArray alloc] init];
		inlinequotes.ranges = [[NSMutableArray alloc] init];
		spoilers.values = [[NSMutableArray alloc] init];
		spoilers.ranges = [[NSMutableArray alloc] init];
	}
	return self;
}

- (id)initTestPost {
	if((self = [self init])) {
		ID = 1;
		thread = 0;
		index = 0;
		board = @"b";
		user = [[CKUser alloc] initWithUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		                                           @"Name",@"Name",
		                                           @"Trip",@"Tripcode",
		                                           @"Secure",@"Secure Tripcode",
		                                           @"email@example.com",@"Email",
		                                           [NSNumber numberWithInt:CK_PRIV_ADMIN],@"Privilege",nil]];

		NSBundle* classbundle = [NSBundle bundleForClass:[self class]];
		image = [[CKImage alloc] initByReferencingURL:[classbundle URLForImageResource:@"ChanKit.png"]];
		image.thumbnail = [CKImage imageWithContentsOfURL:[classbundle URLForImageResource:@"ChanKit_thumb.png"]];
		[image setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:
		                      @"KRUrxKSynSfP8h/eYN8yqA==",@"MD5",
		                      [NSNumber numberWithUnsignedInteger:328230],@"Size",
		                      [NSValue valueWithSize:NSMakeSize(512.0,512.0)],@"Resolution",
		                      [[[NSFileManager defaultManager] attributesOfItemAtPath:
		                         [classbundle pathForImageResource:@"ChanKit.png"] error:nil] fileModificationDate],@"Timestamp",nil]];

		subject = @"Subject";
		comment = @">>1\n>Inline\nComment\n(ADMIN MESSAGE)";
		date = [[NSDate alloc] init];
		OP = YES;
		banned = YES;
		sticky = YES;
		closed = YES;
		[adminmessages.values addObject:@"(ADMIN MESSAGE)"];
		[adminmessages.ranges addObject:[NSValue valueWithRange:NSMakeRange(20,15)]];
		[quotes.values addObject:self];
		[quotes.ranges addObject:[NSValue valueWithRange:NSMakeRange(0,3)]];
		[inlinequotes.values addObject:@">Inline"];
		[inlinequotes.ranges addObject:[NSValue valueWithRange:NSMakeRange(4,7)]];
	}
	return self;
}
+ (CKPost*)testPost { return [[[self alloc] initTestPost] autorelease]; }

- (BOOL)parseURL:(NSURL*)url {
	if(url && url != URL && ![[url absoluteURL] isEqual:[URL absoluteURL]]) {
		[URL release];
		[board release];
		URL = [url copy];
		board = [[CKUtil parseBoard:URL] retain];
		thread = [CKUtil parseThreadID:URL];
		ID = [CKUtil parsePostID:URL];
		OP = ID == thread;
		DLog(@"URL: %@",URL);
		DLog(@"Board: %@",board);
		DLog(@"Thread ID: %d",thread);
		DLog(@"Post ID: %d",ID);
		DLog(@"OP: %d",OP);
		return board && ID >= 0;
	}
	return url != nil;
}

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [self init]) && [self parseURL:url])
		return self;
	[self release];
	return nil;
}
+ (CKPost*)postReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url{
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	[self release];
	return nil;
}
+ (CKPost*)postFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (id)initWithXML:(NSXMLNode*)doc threadContext:(CKThread*)context {
	if((self = [self initByReferencingURL:[NSURL URLWithString:[doc URI]]]))
		[self populate:doc threadContext:context];
	return self;
}
+ (CKPost*)postFromXML:(NSXMLNode*)doc threadContext:(CKThread*)context { return [[[self alloc] initWithXML:doc threadContext:context] autorelease]; }

- (void)dealloc {
	[URL release];
	[board release];
	[user release];
	[image release];
	[date release];
	[subject release];
	[comment release];
	[quotes.values release];
	[quotes.ranges release];
	[inlinequotes.values release];
	[inlinequotes.ranges release];
	[adminmessages.values release];
	[adminmessages.ranges release];
	[super dealloc];
}

- (int)populate { 
	NSXMLDocument* doc;
	int error = [CKUtil fetchXML:&doc fromURL:URL];
	if(error != CK_ERR_SUCCESS)
		return error;
	// URL may have changed during fetch due to redirects
	if(![self parseURL:[NSURL URLWithString:[doc URI]]])
		return CK_ERR_REDIRECT;
	deleted = NO;
	[self populate:doc threadContext:nil];
	if(deleted) return CK_ERR_NOTFOUND;
	return CK_ERR_SUCCESS;
}

- (void)populate:(NSXMLNode*)doc threadContext:(CKThread*)context {
	if(![doc level]) {
		// doc is root node
		NSString* rootpath = OP ? [[CKRecipe sharedRecipe] lookup:@"Post.OP"] :
		                        [NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Post.Index"],self.IDString];
		NSArray* nodes = [doc nodesForXPath:rootpath error:NULL];
		if([nodes count]) [self populate:[nodes objectAtIndex:0] threadContext:context];
		else deleted = YES; // Unless a bogus URL was sent, but that's the client's problem; it shouldn't ever happen internally.
		return;
	}
	if(!OP) {
		// It would be nice if this could simply be taken from the xmlnode's index, thank Yotsuba and tidy's throwing out empty elements
		if((index = [[[[CKRecipe sharedRecipe] lookup:@"Thread.Replies" inDocument:[doc rootDocument]]
					  componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] indexOfObject:self.IDString]) == NSNotFound) {
			deleted = YES;
			return;
		}
		index++;
	}
	DLog(@"Index: %lu",(unsigned long)index);

	sticky = [[CKRecipe sharedRecipe] lookup:@"Post.Sticky" inDocument:doc] != nil;
	closed = [[CKRecipe sharedRecipe] lookup:@"Post.Closed" inDocument:doc] != nil;
	DLog(@"Sticky: %d",sticky);
	DLog(@"Closed: %d",closed);
	
	NSArray* abbr = [doc nodesForXPath:[[CKRecipe sharedRecipe] lookup:@"Post.Abbreviated"] error:NULL];
	if((abbreviated = [abbr count]))
		[[abbr objectAtIndex:0] detach];
	DLog(@"Abbreviated: %d",abbreviated);

	comment = [[[CKRecipe sharedRecipe] lookup:@"Post.Comment" inDocument:doc] retain];
	DLog(@"Comment:\n%@",comment);

	NSUInteger last = 0;
	[adminmessages.values removeAllObjects];
	[adminmessages.ranges removeAllObjects];
	adminmessages.count = 0;
	for(NSString* msg in [[[CKRecipe sharedRecipe] lookup:@"Post.Admin" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
		[adminmessages.values addObject:msg];
		NSRange range = [comment rangeOfString:msg options:0 range:NSMakeRange(last,[comment length] - last)];
		[adminmessages.ranges addObject:[NSValue valueWithRange:range]];
		adminmessages.count++;
		last = range.location + range.length;
	}
	DLog(@"Admin Messages: %@",adminmessages.values);

	banned = [[adminmessages.values filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF = %@",[[CKRecipe sharedRecipe] lookup:@"Post.BanMessage"]]] count];
	DLog(@"Banned: %d",banned);

	if(!populated) {
		subject = [[[CKRecipe sharedRecipe] lookup:@"Post.Subject" inDocument:doc] retain];
		DLog(@"Subject: %@", subject);

		NSString* datestr = [[CKRecipe sharedRecipe] lookup:@"Post.Timestamp" inDocument:doc];
		if(datestr)
			date = [[NSDate alloc] initWithTimeIntervalSince1970:[datestr doubleValue]];
		else {
			NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
			[formatter setTimeZone:[NSTimeZone timeZoneWithName:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Timezone"]]];
			[formatter setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Format"]];
			date = [[formatter dateFromString:[[CKRecipe sharedRecipe] lookup:@"Post.Date" inDocument:doc]] retain];
			[formatter release];
		}
		DLog(@"Date: %@",date);

		user = [[CKUser alloc] initWithXML:doc];
		image = [[CKImage alloc] initWithXML:doc];

		last = 0;
		for(NSString* quote in [[[CKRecipe sharedRecipe] lookup:@"Post.InlineQuotes" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
			[inlinequotes.values addObject:quote];
			NSRange range = [comment rangeOfString:quote options:0 range:NSMakeRange(last,[comment length] - last)];
			[inlinequotes.ranges addObject:[NSValue valueWithRange:range]];
			inlinequotes.count++;
			last = range.location + range.length;
		}
		DLog(@"Inline Quotes: %@",inlinequotes.values);

		last = 0;
		for(NSString* spoiler in [[[CKRecipe sharedRecipe] lookup:@"Post.Spoilers" inDocument:doc] componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]) {
			[spoilers.values addObject:spoiler];
			NSRange range = [comment rangeOfString:spoiler options:0 range:NSMakeRange(last,[comment length] - last)];
			[spoilers.ranges addObject:[NSValue valueWithRange:range]];
			spoilers.count++;
			last = range.location + range.length;
		}
		DLog(@"Spoilers: %@",spoilers.values);

		for(NSXMLNode* quote in [doc nodesForXPath:[[CKRecipe sharedRecipe] lookup:@"Post.Quotes.XML"] error:NULL]) {
			NSString* href = [[CKRecipe sharedRecipe] lookup:@"Post.Quotes.URL" inDocument:quote];
			NSString* text = [[CKRecipe sharedRecipe] lookup:@"Post.Quotes.ID" inDocument:quote];
			// A URL will pop up here for cross-board links, so we have to check that it actually goes somewhere. Thanks Yotsuba!
			if(href && text) {
				CKPost* post;
				NSRange range;
				NSString* xthread;
				int qid = [[href stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.ID"] capture:1L] intValue];
				DLog(@"Quote %d: %@",qid,href);
				NSUInteger idx = [quotes.values indexOfObjectWithOptions:NSEnumerationReverse passingTest:^(id q, NSUInteger ndx, BOOL *stop) {
					return *stop = [q ID] == qid;
				}];
				if(idx == NSNotFound) {
					if((post = [context postWithID:qid])); // Use this, don't do anything
					else if(qid == ID) // They quoted themself :|
						post = self;
					else if([href isMatchedByRegex:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.CrossBoard"]])
						// Cross-board quote, it will be resolved on the first call to populate:
						post = [CKPost postReferencingURL:[NSURL URLWithString:href relativeToURL:URL]];
					else if((xthread = [href stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.CrossThread"] capture:1L]))
						// Same board, different thread
						// When populating from a page, all quotes are treated as such
						post = [CKPost postReferencingURL:[NSURL URLWithString:xthread relativeToURL:URL]];
					else {
						// Regular quote
						NSString* uri = [[doc rootDocument] URI];
						[[doc rootDocument] setURI:[[NSURL URLWithString:href relativeToURL:URL] absoluteString]];
						post = [CKPost postFromXML:[doc rootDocument] threadContext:context];
						[[doc rootDocument] setURI:uri];
					}
					range = [comment rangeOfString:text];
				}
				else {
					post = [quotes.values objectAtIndex:idx];
					NSRange previous = [[quotes.ranges objectAtIndex:idx] rangeValue];
					last = previous.location + previous.length;
					range = [comment rangeOfString:text options:0 range:NSMakeRange(last,[comment length] - last)];
				}
				if(post) {
					[quotes.values addObject:post];
					[quotes.ranges addObject:[NSValue valueWithRange:range]];
					quotes.count++;
				}
			}
		}
		populated = YES;
	}
}

@synthesize URL;
@synthesize ID;
@synthesize thread;
@synthesize index;
@synthesize board;
@synthesize user;
@synthesize image;
@synthesize subject;
@synthesize date;
@synthesize OP;
@synthesize sticky;
@synthesize closed;
@synthesize banned;
@synthesize deleted;
@synthesize comment;
@synthesize abbreviated;

- (NSArray*)quotes { return [[quotes.values retain] autorelease]; }
- (NSArray*)inlinequotes { return [[inlinequotes.values retain] autorelease]; }
- (NSArray*)spoilers { return [[spoilers.values retain] autorelease]; }
- (NSArray*)adminmessages { return [[adminmessages.values retain] autorelease]; }

- (NSString*)IDString { return [NSString stringWithFormat:@"%d",ID]; }

- (NSString*)description {
	NSMutableString* desc = [NSMutableString string];
	if(subject) [desc appendFormat:@"%@ ",subject];
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"MM/dd/yy(EEE)HH:mm:ss"];
	[desc appendFormat:@"%@ %@ No.%d ",user,[formatter stringFromDate:date],ID];
	[formatter release];
	if(banned) [desc appendString:@"☠"];
	if(deleted) [desc appendString:@"⌫"];
	if(closed) [desc appendString:@"✖"];
	if(sticky) [desc appendString:@"☌"];
	if(image) [desc appendString:[image description]];
	if(comment) [desc appendFormat:@"\n%@",comment];
	if(abbreviated) [desc appendString:@" (…)"];
	return desc;
}

- (NSString*)prettyPrint {
	NSMutableString* desc = [NSMutableString string];
	if(subject) [desc appendFormat:@"\e[1;34m%@\e[0m ",subject];
	NSDateFormatter* formatter = [[NSDateFormatter alloc] init];
	[formatter setDateFormat:@"MM/dd/yy(EEE)HH:mm:ss"];
	[desc appendFormat:@"%@ %@ No.%d",[user prettyPrint],[formatter stringFromDate:date],ID];
	[formatter release];
	if(banned) [desc appendString:@" \e[0;31m☠\e[0m"];
	if(deleted) [desc appendString:@" \e[0;31m⌫\e[0m"];
	if(closed) [desc appendString:@" \e[0;31m✖\e[0m"];
	if(sticky) [desc appendString:@" \e[0;33m☌\e[0m"];
	if(image) [desc appendString:[image prettyPrint]];
	if(comment) {
		NSMutableString* formatted = [NSMutableString stringWithString:comment];
		for(int i = 0; i < quotes.count; i++) {
			NSRange range = [[quotes.ranges objectAtIndex:i] rangeValue];
			[formatted replaceCharactersInRange:NSMakeRange(range.location+i*11,range.length) withString:
			   [NSString stringWithFormat:@"\e[4;31m%@\e[0m",[[quotes.values objectAtIndex:i] quoteRelativeToPost:self]]];
		}
		// This is completely obscene but it's the shortest way to deal with this jacked up attributed string situation
		for(int i = 0; i < inlinequotes.count; i++) {
			NSUInteger start = [[inlinequotes.ranges objectAtIndex:i] rangeValue].location + i * 11;
			[formatted replaceCharactersInRange:[formatted rangeOfString:[inlinequotes.values objectAtIndex:i] options:0 range:NSMakeRange(start,[formatted length]-start)]
			                         withString:[NSString stringWithFormat:@"\e[0;32m%@\e[0m",[inlinequotes.values objectAtIndex:i]]];
		}
		for(int i = 0; i < adminmessages.count; i++) {
			NSUInteger start = [[adminmessages.ranges objectAtIndex:i] rangeValue].location + i * 11;
			[formatted replaceCharactersInRange:[formatted rangeOfString:[adminmessages.values objectAtIndex:i] options:0 range:NSMakeRange(start,[formatted length]-start)]
		                             withString:[NSString stringWithFormat:@"\e[1;31m%@\e[0m",[adminmessages.values objectAtIndex:i]]];
		}
		for(int i = 0; i < spoilers.count; i++) {
			NSUInteger start = [[spoilers.ranges objectAtIndex:i] rangeValue].location + i * 12;
			[formatted replaceCharactersInRange:[formatted rangeOfString:[spoilers.values objectAtIndex:i] options:0 range:NSMakeRange(start,[formatted length]-start)]
		                             withString:[NSString stringWithFormat:@"\e[40;30m%@\e[0m",[spoilers.values objectAtIndex:i]]];
		}
		[desc appendFormat:@"\n\n\t%@",[[formatted componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] componentsJoinedByString:@"\n\t"]];
	}
	if(abbreviated) [desc appendString:@"\n\t(…)"];
	return desc;
}

- (NSString*)commentFilteringQuotes {
	return [comment stringByReplacingOccurrencesOfRegex:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.Regex"] withString:[NSString string]];
}

- (BOOL)commentContains:(NSString*)astring {
	return [comment rangeOfString:astring].location != NSNotFound;
}

- (BOOL)quoted:(CKPost*)post {
	return [quotes.values indexOfObjectPassingTest:^(id quote, NSUInteger idx, BOOL *stop){return *stop = [quote ID] == [post ID];}] != NSNotFound;
}

- (NSString*)quoteRelativeToPost:(CKPost*)post {
	if([board isEqualToString:post.board])
		return [NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.Format"],ID];
	return [NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.CrossBoardFormat"],board,ID];
}

- (NSXMLNode*)generateXML {
	NSXMLNode* xmluser = [user XMLRepresentation];
	NSXMLNode* xmlfile = [image XMLRepresentation];

	NSXMLElement* xmlsubject = [NSXMLElement elementWithName:@"span"
	                                                children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:subject]]
	                                              attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class" stringValue:@"subject"]]];

	NSMutableArray* piecemeal = [NSMutableArray array];
	NSUInteger lastend = 0;
	NSUInteger len = [comment length];
	for(NSUInteger i = 0; i < quotes.count; i++) {
		NSRange range = [[quotes.ranges objectAtIndex:i] rangeValue];
		CKPost* post = [quotes.values objectAtIndex:i];
		[piecemeal addObject:[NSXMLNode textWithStringValue:[comment substringWithRange:NSMakeRange(lastend,range.location - lastend)]]];
		[piecemeal addObject:[NSXMLElement elementWithName:@"a"
		                                          children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:[NSString stringWithFormat:@">>%d",post.ID]]]
		                                        attributes:[NSArray arrayWithObjects:
		                                                   [NSXMLNode attributeWithName:@"class" stringValue:@"quote"],
		                                                   [NSXMLNode attributeWithName:@"href" stringValue:[NSString stringWithFormat:@"#%d",post.ID]],
		                                                   nil]]];//gonna have to do better than this
		lastend = range.location + range.length;
	}
	[piecemeal addObject:[NSXMLNode textWithStringValue:[comment substringWithRange:NSMakeRange(lastend,len - lastend)]]];

	// ... eventually we return an <li>
	return nil;
}

- (BOOL)isEqual:(id)other { return [self hash] == [other hash]; }
- (NSUInteger)hash { return [URL hash]; }

@end
