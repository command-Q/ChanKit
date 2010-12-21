/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKPoster.m - Posting data to the board.
 */

#import "CKPoster.h"
#import "CKBoard.h"

@implementation CKPoster

- (id)initWithPostingDictionary:(NSDictionary*)dict {
	if((self = [self initWithURL:[dict objectForKey:@"URL"]]) || (self = [super init])) {
		user = [[CKUser alloc] initWithUserInfo:dict];
		for(NSString* key in dict) {
			if([key isEqualToString:@"Subject"])
				subject = [[dict objectForKey:key] retain];
			else if([key isEqualToString:@"Comment"])
				comment = [[dict objectForKey:key] retain];
			else if([key isEqualToString:@"File"])
				file = [[[dict objectForKey:key] stringByStandardizingPath] retain];
			else if([key isEqualToString:@"Verification"]) {
				captcha.challenge = [[dict objectForKey:key] retain];
				captcha.verification = @"manual_challenge";
			}
		}
		DLog(@"Subject: %@",subject);
		DLog(@"Comment: %@",comment);
		DLog(@"File: %@",file);
		DLog(@"Verification: %@",captcha.verification);
	}
	return self;
}
+ (CKPoster*)posterWithDictionary:(NSDictionary*)dict { return [[[self alloc] initWithPostingDictionary:dict] autorelease]; }

- (id)initByReferencingURL:(NSURL*)url {
	if(self = [super init]) {
		URL = [url retain];
		DLog(@"URL: %@",URL);
	}
	return self;
}

- (id)initWithURL:(NSURL*)url{
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	return nil;
}
+ (CKPoster*)posterForURL:(NSURL*)url { return [[[self alloc] initWithURL:url] autorelease]; }

- (id)initWithXML:(NSXMLNode*)doc {
	if((self = [self initByReferencingURL:[NSURL URLWithString:[doc URI]]]))
		[self populate:doc];
	return self;
}
+ (CKPoster*)posterForXML:(NSXMLNode*)doc { return [[[self alloc] initWithXML:doc] autorelease]; }

- (int)populate { 
	int error;
	NSXMLDocument* doc;
	if((error = [CKUtil fetchXML:&doc fromURL:URL]))
		return error;
	[self populate:doc];
	return 0;
}
- (void)populate:(NSXMLNode*)doc {
	NSURL* captchaurl = [NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster/Captcha/URL" inDocument:doc]];
	NSXMLDocument* captchadoc = [[[NSXMLDocument alloc] initWithContentsOfURL:captchaurl options:NSXMLDocumentTidyHTML error:nil] autorelease];
	captcha.challenge = [[[CKRecipe sharedRecipe] lookup:@"Poster/Captcha/Challenge" inDocument:captchadoc] retain];
	captcha.image = [[NSImage alloc] initWithContentsOfURL:
					 [NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster/Captcha/Image" inDocument:captchadoc] 
							relativeToURL:captchaurl]];
	action = [[NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster/URL" inDocument:doc]] retain];
	board = [[CKBoard alloc] initByReferencingURL:[[NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Board/Location" inDocument:doc] 
														 relativeToURL:URL] absoluteURL]];
	DLog(@"Posting URL: %@",action);
	DLog(@"Captcha Challenge: %@",captcha.challenge);
}


- (void)dealloc {
	[URL release];
	[action release];
	[user release];
	[subject release];
	[comment release];
	[file release];
	[captcha.challenge release];
	[captcha.image release];
	[captcha.verification release];
	[request release];
	[board release];
	[super dealloc];
}

@synthesize user;
@synthesize subject;
@synthesize comment;
@synthesize file;

- (NSString*)verification { return [captcha.verification copy]; }
- (void)setVerification:(NSString*)ver { captcha.verification = [ver retain]; }
- (NSImage*)captcha { return [captcha.image copy]; }

- (BOOL)verify:(NSString*)captchaverification {
	// Needs work
	NSString* content = [NSString stringWithFormat:@"recaptcha_challenge_field=%@&recaptcha_response_field=%@",
						 captcha.challenge,captcha.verification];	
	NSMutableURLRequest* crequest = [NSMutableURLRequest requestWithURL:
		[NSURL URLWithString:@"http://www.google.com/recaptcha/api/noscript?k=6Ldp2bsSAAAAAAJ5uyx_lx34lJeEpTLVkP5k04qc"]];
	[crequest setHTTPMethod:@"POST"];
	[crequest setValue:[NSString stringWithFormat:@"%d",[content length]] forHTTPHeaderField:@"Content-Length"];
	[crequest setValue:@"application/x-www-form-urlencoded" forHTTPHeaderField:@"Content-Type"];
	[crequest setHTTPBody:[content dataUsingEncoding:NSASCIIStringEncoding]];
	NSData* data = [NSURLConnection sendSynchronousRequest:crequest returningResponse:nil error:nil];
	NSXMLDocument* response = [[NSXMLDocument alloc] initWithData:data options:NSXMLDocumentTidyHTML error:nil];
	NSArray* nodes;
	if(![nodes = [response nodesForXPath:@"/html/body/textarea/text()" error:nil] count])
		return NO;
	captcha.challenge = [[nodes objectAtIndex:0] stringValue];
	captcha.verification = @"manual_challenge";
	return YES;
}

- (void)prepare {
	request = [[NSMutableURLRequest alloc] initWithURL:action];
	[request setHTTPMethod:@"POST"];
	[request addValue:[NSString stringWithFormat:@"multipart/form-data; boundary=%@",CK_FORM_BOUNDARY] forHTTPHeaderField: @"Content-Type"];
	[request addValue:[URL absoluteString] forHTTPHeaderField:@"Referer"];
	NSMutableData* body = [NSMutableData data];
	[body appendData:[user generatePostingData]];
	
	NSMutableString* data = [NSMutableString string];
	// TODO: field names from recipe
	if(subject) [data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"sub\"\r\n\r\n%@",CK_FORM_BOUNDARY,subject];
	if(comment) [data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"com\"\r\n\r\n%@",CK_FORM_BOUNDARY,comment];
	if(captcha.verification)
		[data appendFormat:	@"\r\n--%@\r\nContent-Disposition: form-data; name=\"recaptcha_challenge_field\"\r\n\r\n%@"
							 "\r\n--%@\r\nContent-Disposition: form-data; name=\"recaptcha_response_field\"\r\n\r\n%@",
							CK_FORM_BOUNDARY,captcha.challenge,CK_FORM_BOUNDARY,captcha.verification];
	[data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"mode\"\r\n\r\nregist",CK_FORM_BOUNDARY];
	if([[URL absoluteString] isMatchedByRegex:@"http://boards.4chan.org/.+/res/.+"])
		[data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"resto\"\r\n\r\n%@",
							CK_FORM_BOUNDARY,[[URL absoluteString] stringByMatching:@".*/([^#]+)" capture:1L]];
	
	if(file) [data appendFormat:
		 @"\r\n--%@\r\nContent-Disposition: form-data; name=\"upfile\"; filename=\"%@\"\r\nContent-Type: application/octet-stream\r\n\r\n",
													CK_FORM_BOUNDARY,[file lastPathComponent]];
	[body appendData:[data dataUsingEncoding:NSUTF8StringEncoding]];
	DLog(@"POST Data:\n%@",[NSString stringWithUTF8String:[body bytes]]);
	if(file) [body appendData:[NSData dataWithContentsOfFile:file]];
	[body appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n",CK_FORM_BOUNDARY] dataUsingEncoding:NSUTF8StringEncoding]];

	[request addValue:[NSString stringWithFormat:@"%d",[body length]] forHTTPHeaderField:@"Content-Length"];
	[request setHTTPBody:body];
}

- (CKPost*)post:(int*)error attempt:(BOOL (^)(int idno))test {
	if(!request) [self prepare];
	
	int idno;
	do {
		NSAutoreleasePool* loop = [[NSAutoreleasePool alloc] init];
		idno = [board newestPostID];
		[loop drain];
	} while(!test(idno));
	
	return [self post:error];
}

- (CKPost*)post:(int*)error {
	if(!request) [self prepare];
	
	NSData* response = [NSURLConnection sendSynchronousRequest:request returningResponse:nil error:nil];
	DLog(@"Response:\n%@",[[[NSString alloc] initWithData:response encoding:NSUTF8StringEncoding] autorelease]);

	NSXMLDocument* doc = [[[NSXMLDocument alloc] initWithData:response options:NSXMLDocumentTidyHTML error:nil] autorelease];
	*error = CK_POSTERR_SUCCESS;
	if(!doc)
		*error = CK_POSTERR_UNDEFINED;		
	else if([[CKRecipe sharedRecipe] lookup:@"Poster/Response/Captcha" inDocument:doc])
		*error = CK_POSTERR_VERIFICATION;
	else if([[CKRecipe sharedRecipe] lookup:@"Poster/Response/Duplicate" inDocument:doc])
		*error = CK_POSTERR_DUPLICATE;
	else if([[CKRecipe sharedRecipe] lookup:@"Poster/Response/Flood" inDocument:doc])
		*error = CK_POSTERR_FLOOD;
	else if([[CKRecipe sharedRecipe] lookup:@"Poster/Response/Disallowed" inDocument:doc])
		*error = CK_POSTERR_DISALLOWED;
	else if([[CKRecipe sharedRecipe] lookup:@"Poster/Response/NotFound" inDocument:doc])
		*error = CK_POSTERR_NOTFOUND;
	else {
		NSString* resboard = [[CKRecipe sharedRecipe] lookup:@"Poster/Response/URL" inDocument:doc];
		NSString* resthread = [[CKRecipe sharedRecipe] lookup:@"Poster/Response/Thread" inDocument:doc];
		NSString* respost = [[CKRecipe sharedRecipe] lookup:@"Poster/Response/Post" inDocument:doc];
		NSString* resurl = [NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Poster/Response/Format"],resboard,resthread,respost];
		DLog(@"Got Board: %@",resboard);
		DLog(@"Got Thread: %@",resthread);
		DLog(@"Got Post: %@",respost);
		DLog(@"URL: %@",resurl);
		if(resthread && respost && resboard)
			return [CKPost postFromURL:[NSURL URLWithString:resurl]];
		*error = CK_POSTERR_UNDEFINED;
	}
	return nil;
}

@end
