/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2009-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKPost.m - Data from a single post. Core building block of the framework.
 */

#import "CKUser.h"
#import "CKImage.h"
#import "CKPost.h"
#import "CKThread.h"

@implementation CKPost

// Object methods
- (id)init {
	if(self = [super init]) {
		quotes.values = [[NSMutableArray alloc] init];
		quotes.ranges = [[NSMutableArray alloc] init];
		adminmessages.values = [[NSMutableArray alloc] init];
		adminmessages.ranges = [[NSMutableArray alloc] init];
		inlinequotes.values = [[NSMutableArray alloc] init];
		inlinequotes.ranges = [[NSMutableArray alloc] init];
	}
	return self;
}

- (id)initTestPost {
	if(self = [self init]) {
		ID = 1;
		thread = 0;
		index = 0;
		board = @"b";
		NSDictionary* uinfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Name",@"Name",@"Trip",@"Tripcode",
							   @"Secure",@"Secure Tripcode",@"e@ma.il",@"Email",
							   [NSNumber numberWithInt:CK_PRIV_ADMIN],@"Privilege",nil];
		user = [[CKUser alloc] initWithUserInfo:uinfo];
		
		NSBundle* classbundle = [NSBundle bundleForClass:[self class]];
		image = [[CKImage alloc] initByReferencingURL:[classbundle URLForImageResource:@"ChanKit.png"]];
		image.thumbnail = [[CKImage alloc] initWithContentsOfURL:[classbundle URLForImageResource:@"ChanKit_thumb.png"]];
		[image setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:	
							@"KRUrxKSynSfP8h/eYN8yqA==",@"MD5",
							[NSNumber numberWithUnsignedInteger:328230],@"Size",
							[NSValue valueWithSize:NSMakeSize(512.0,512.0)],@"Resolution",
							[[[NSFileManager defaultManager] attributesOfItemAtPath:
							[classbundle pathForImageResource:@"ChanKit.png"] error:nil] fileModificationDate],
							@"Timestamp",nil]];

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

- (id)initByReferencingURL:(NSURL*)url {
	if(url && (self = [self init])) {
		URL = [url retain];
		board = [[CKUtil parseBoard:URL] retain];
		thread = [CKUtil parseThreadID:URL];
		if((OP = ![URL fragment] || [[[URL fragment] stringByMatching:@"\\d+"] intValue] == thread)) 
			ID = thread;
		else 
			ID = [[URL fragment] intValue];
		
		DLog(@"URL: %@",URL);
		DLog(@"Board: %@",board);
		DLog(@"Thread ID: %d",thread);
		DLog(@"Post ID: %d",ID);
		DLog(@"OP: %d",OP);	
	}
	return self;
}
+ (CKPost*)postReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithURL:(NSURL*)url{
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	return nil;
}
+ (CKPost*)postFromURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (id)initWithXML:(NSXMLNode*)doc threadContext:(CKThread*)thr {
	if((self = [self initByReferencingURL:[NSURL URLWithString:[doc URI]]])) {
	/*	CKPost* inthread;
		if((inthread = [thr postWithID:ID])) return self = [inthread retain];
		thread = thr.ID;
	*/	[self populate:doc];
	}
	return self;
}
+ (CKPost*)postFromXML:(NSXMLNode*)doc threadContext:(CKThread*)thr { return [[[self alloc] initWithXML:doc threadContext:thr] autorelease]; }

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
	int error;
	NSXMLDocument* doc;
	if((error = [CKUtil fetchXML:&doc fromURL:URL]))
		return error;
	[self populate:doc];
	return 0;
}

- (void)populate:(NSXMLNode*)doc {
	if(![doc level]) {
		// doc is root node
		NSString* rootpath = OP ? [[CKRecipe sharedRecipe] lookup:@"Post.OP"] : 
									[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Post.Index"],self.IDString];
		NSArray* nodes = [doc nodesForXPath:rootpath error:NULL];
		if([nodes count]) [self populate:[nodes objectAtIndex:0]];
		return;
	}
	index = OP ? 0 : [[[doc rootDocument] nodesForXPath:[[CKRecipe sharedRecipe] lookup:@"Post.Indexes"] error:nil] indexOfObject:doc]+1;	
	DLog(@"Index: %d",index);
	
	subject = [[[CKRecipe sharedRecipe] lookup:@"Post.Subject" inDocument:doc] retain];
	DLog(@"Subject: %@", subject);

	NSDateFormatter* dateformat = [[[NSDateFormatter alloc] init] autorelease];
	[dateformat setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Format"]];
	NSString* datestr = [[CKRecipe sharedRecipe] lookup:@"Post.Date" inDocument:doc];
	if(!(date = [dateformat dateFromString:datestr])) {
		[dateformat setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Alternate"]];
		date = [[dateformat dateFromString:datestr] retain];
	}
	DLog(@"Date: %@",date);

	user = [[CKUser alloc] initWithXML:doc];

	sticky = [[CKRecipe sharedRecipe] lookup:@"Post.Sticky" inDocument:doc] != nil;
	closed = [[CKRecipe sharedRecipe] lookup:@"Post.Slosed" inDocument:doc] != nil;
	DLog(@"Sticky: %d",sticky);
	DLog(@"Closed: %d",closed);
	
	image = [[CKImage alloc] initWithXML:doc];

	comment = [[[CKRecipe sharedRecipe] lookup:@"Post.Comment" inDocument:doc] retain];
	DLog(@"Comment:\n%@",comment);

	[adminmessages.values addObjectsFromArray:[[[CKRecipe sharedRecipe] lookup:@"Post.Admin" inDocument:doc] 
					 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];
	for(NSString* msg in adminmessages.values)
		[adminmessages.ranges addObject:[NSValue valueWithRange:[comment rangeOfString:msg]]];
	if((adminmessages.count = [adminmessages.values count]) > [adminmessages.ranges count])
		adminmessages.count = [adminmessages.ranges count];

	DLog(@"Admin Messages: %@",adminmessages.values);
	
	banned = [[adminmessages.values filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF = %@",
														  [[CKRecipe sharedRecipe] lookup:@"Post.BanMessage"]]] count];
	DLog(@"Banned: %d",banned);
	
	[inlinequotes.values addObjectsFromArray:[[[CKRecipe sharedRecipe] lookup:@"Post.InlineQuotes" inDocument:doc]
					componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]]];	
	for(NSString* quote in inlinequotes.values)
		[inlinequotes.ranges addObject:[NSValue valueWithRange:[comment rangeOfString:quote]]];
	if((inlinequotes.count = [inlinequotes.values count]) > [inlinequotes.ranges count])
		inlinequotes.count = [inlinequotes.ranges count];
	DLog(@"Inline Quotes: %@",inlinequotes.values);
	
	//Quotes broken for now, problem with CKUtil
	return;
	NSArray* quoterefs = [[[CKRecipe sharedRecipe] lookup:@"Post.Quotes.URL" inDocument:doc] 
						 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	NSArray* quotestrings = [[[CKRecipe sharedRecipe] lookup:@"Post.Quotes.ID" inDocument:doc] 
						 componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
	DLog(@"Quotes: %@",quotestrings);
	// some bugs here
	// also do other links
	for(int i = 0; i < [quoterefs count]; i++) {
		CKPost* post;
		NSRange range;
		NSString* qurl = [quoterefs objectAtIndex:i];
		DLog(@"Quote URL: %@",qurl);		
		int qid = [[qurl stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.ID"] capture:1L] intValue];
		NSUInteger idx;
		if(NSNotFound == (idx = [quotes.values indexOfObjectPassingTest:^(id quote, NSUInteger ndx, BOOL *stop) {
			return *stop = [quote ID] == qid;}])) {
			if(qid == ID)
				 // They quoted themself :|
				post = self;
			else if([qurl isMatchedByRegex:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.CrossThread"]]) 
				// Same board, different thread
				post = [CKPost postReferencingURL:[[URL URLByDeletingLastPathComponent] URLByAppendingPathComponent:qurl]];
			else if([qurl isMatchedByRegex:[[CKRecipe sharedRecipe] lookup:@"Definitions.Quotes.CrossBoard"]]) {
				// Cross-board quote, we have to resolve it
				NSXMLDocument* request = [[[NSXMLDocument alloc] initWithContentsOfURL:[NSURL URLWithString:qurl] 
																			  options:NSXMLDocumentTidyHTML error:NULL] autorelease];
				if(request)
					post = [[CKPost alloc] initByReferencingURL:
							[NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Post.Redirect" inDocument:request]]];
				else
					DLog(@"Bad quote: %@",qurl);
			}
			else {
				// Regular quote
				NSString* uri = [[doc rootDocument] URI];
				[[doc rootDocument] setURI:[[CKUtil changePost:URL toPost:qid] absoluteString]];
			//	post = [[CKPost alloc] initWithXML:[doc rootDocument] threadContext:thread];
				[[doc rootDocument] setURI:uri];
			}
			range = [comment rangeOfString:[quotestrings objectAtIndex:i]];
		}
		else {
			post = [quotes.values objectAtIndex:idx];
			NSRange previous = [[quotes.ranges objectAtIndex:idx] rangeValue];
			NSUInteger start = previous.location + previous.length;
			range = [comment rangeOfString:[quotestrings objectAtIndex:i] options:0 range:NSMakeRange(start,[comment length] - start)];
		}
		if(post) {
			[quotes.values addObject:post];
			[quotes.ranges addObject:[NSValue valueWithRange:range]];			
		}
	}
	if((quotes.count = [quotes.values count]) > [quotes.ranges count])
		quotes.count = [quotes.ranges count];
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

- (NSArray*)quotes { return quotes.values; }
- (NSArray*)inlinequotes { return inlinequotes.values; }
- (NSArray*)adminmessages { return adminmessages.values; }
- (void)addAdminMessage:(NSString*)newcomment {
	//todo
}

- (NSString*)IDString { return [NSString stringWithFormat:@"%d",ID]; }

- (NSString*)description {
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Format"]];
	NSMutableString* desc = [NSMutableString string];
	if(subject) [desc appendFormat:@"%@ ",subject];
	[desc appendFormat:@"%@ %@ No.%d ",user,[formatter stringFromDate:date],ID];
	if(banned) [desc appendString:@"☠"];
	if(deleted) [desc appendString:@"⌫"];
	if(closed) [desc appendString:@"⦸✖"];
	if(sticky) [desc appendString:@"☌"];
	if(image) [desc appendString:[image description]];
	if(comment) [desc appendFormat:@"\n%@",comment];
	return desc;
}

- (NSString*)prettyPrint {
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Format"]];
	NSMutableString* desc = [NSMutableString string];
	if(subject) [desc appendFormat:@"\e[1;34m%@\e[0m ",subject];
	[desc appendFormat:@"%@ %@ No.%d ",[user prettyPrint],[formatter stringFromDate:date],ID];
	if(banned) [desc appendString:@"\e[0;31m☠\e[0m"];
	if(deleted) [desc appendString:@"\e[0;31m⌫\e[0m"];
	if(closed) [desc appendString:@"⦸\e[0;31m✖\e[0m"];
	if(sticky) [desc appendString:@"\e[0;33m☌\e[0m"];
	if(image) [desc appendString:[image prettyPrint]];
	if(comment) [desc appendFormat:@"\n\n\t%@",
				 [[comment componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]] 
				  componentsJoinedByString:@"\n\t"]];
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

- (NSXMLNode*)generateXML {
	NSXMLNode* xmluser = [user XMLRepresentation];
	NSXMLNode* xmlfile = [image XMLRepresentation];
	
	NSXMLElement* xmlsubject = [NSXMLElement elementWithName:@"span"
													children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:subject]]
												  attributes:[NSArray arrayWithObject:
															  [NSXMLNode attributeWithName:@"class" stringValue:@"subject"]]];
	
	NSMutableArray* piecemeal = [NSMutableArray array];
	NSUInteger lastend = 0;
	NSUInteger len = [comment length];
	for(NSUInteger i = 0; i < quotes.count; i++) {
		NSRange range = [[quotes.ranges objectAtIndex:i] rangeValue];
		CKPost* post = [quotes.values objectAtIndex:i];
		[piecemeal addObject:[NSXMLNode textWithStringValue:[comment substringWithRange:NSMakeRange(lastend,range.location - lastend)]]];
		[piecemeal addObject:[NSXMLElement elementWithName:@"a"
												  children:[NSArray arrayWithObject:
															[NSXMLNode textWithStringValue:[NSString stringWithFormat:@">>%d",post.ID]]]
												attributes:[NSArray arrayWithObjects:
															[NSXMLNode attributeWithName:@"class" stringValue:@"quote"],
															[NSXMLNode attributeWithName:@"href"
																			 stringValue:[NSString stringWithFormat:@"#%d",post.ID]],
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
