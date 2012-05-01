/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKPoster.m - Posting data to the board.
 */

#import "CKUser.h"
#import "CKImage.h"
#import "CKPost.h"
#import "CKBoard.h"
#import "CKPoster.h"

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
				file = [[dict objectForKey:key] retain];
			else if([key isEqualToString:@"Spoiler"])
				spoiler = [[dict objectForKey:key] boolValue];
			else if([key isEqualToString:@"Verification"]) {
				captcha.challenge = [[dict objectForKey:key] retain];
				captcha.verification = @"manual_challenge";
			}
		}
		DLog(@"Subject: %@",subject);
		DLog(@"Comment: %@",comment);
		DLog(@"File: %@",file);
		DLog(@"Spoiler: %d",spoiler);
		DLog(@"Verification: %@",captcha.verification);
	}
	return self;
}
+ (CKPoster*)posterWithDictionary:(NSDictionary*)dict { return [[[self alloc] initWithPostingDictionary:dict] autorelease]; }

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [super init])) {
		URL = [url retain];
		DLog(@"URL: %@",URL);
	}
	return self;
}

- (id)initWithURL:(NSURL*)url{
	if((self = [self initByReferencingURL:url]) && ![self populate])
		return self;
	[self release];
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
	NSURL* captchaurl = [NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster.Captcha.URL" inDocument:doc] relativeToURL:URL];
	NSXMLDocument* captchadoc = [[[NSXMLDocument alloc] initWithContentsOfURL:captchaurl options:NSXMLDocumentTidyHTML error:nil] autorelease];
	captcha.challenge = [[[CKRecipe sharedRecipe] lookup:@"Poster.Captcha.Challenge" inDocument:captchadoc] retain];
	captcha.image = [[CKImage alloc] initWithContentsOfURL:
					 [NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster.Captcha.Image" inDocument:captchadoc] 
							relativeToURL:captchaurl]];
	action = [[NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster.URL" inDocument:doc] relativeToURL:URL] retain];
	int type = [[CKRecipe sharedRecipe] resourceKindForURL:URL];
	NSURL* boardurl;
	switch(type) {
		case CK_RESOURCE_POST:
		case CK_RESOURCE_THREAD:
			board = [[CKBoard alloc] initByReferencingURL:
					 [[NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Board.Location" inDocument:doc] relativeToURL:URL] absoluteURL]];
			break;
		case CK_RESOURCE_BOARD:
			board = [[CKBoard alloc] initByReferencingURL:URL];
			break;
		default:break;
	}
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
//	[request release]; this is causing invalid accesses, but now it's probably a memory leak
	[board release];
	[super dealloc];
}

@synthesize URL;
@synthesize user;
@synthesize subject;
@synthesize comment;
@synthesize file;
@synthesize spoiler;

- (NSString*)verification { return [[captcha.verification retain] autorelease]; }
- (void)setVerification:(NSString*)ver {
	if(ver != captcha.verification) {
		[captcha.verification release];
		captcha.verification = [ver copy];
	}
}
- (CKImage*)captcha { return [[captcha.image retain] autorelease]; }

- (BOOL)verify:(NSString*)captchaverification {
	// Needs work
	if(captchaverification) self.verification = captchaverification;
	ASIFormDataRequest* crequest = [ASIFormDataRequest requestWithURL:
		[NSURL URLWithString:@"http://www.google.com/recaptcha/api/noscript?k=6Ldp2bsSAAAAAAJ5uyx_lx34lJeEpTLVkP5k04qc"]];
	[CKUtil setProxy:[[NSUserDefaults standardUserDefaults] URLForKey:@"CKProxySetting"] onRequest:&crequest];
	[crequest setPostValue:captcha.challenge forKey:@"recaptcha_challenge_field"];
	[crequest setPostValue:captcha.verification forKey:@"recaptcha_response_field"];
	[crequest startSynchronous];
	if([CKUtil validateResponse:crequest] != CK_ERR_SUCCESS)
		return NO;
	NSXMLDocument* response = [[NSXMLDocument alloc] initWithData:[crequest responseData] options:NSXMLDocumentTidyHTML error:nil];
	NSArray* nodes = [response nodesForXPath:@"/html/body/textarea/text()" error:nil];
	[response release];
	if(![nodes count])
		return NO;
	captcha.challenge = [[nodes objectAtIndex:0] stringValue];
	captcha.verification = @"manual_challenge";
	return YES;
}

- (void)prepare {
	request = [[ASIFormDataRequest alloc] initWithURL:action];
	request.timeOutSeconds = CK_PROXY_TIMEOUT;
	[request addRequestHeader:@"Referer" value:[URL absoluteString]];

	NSMutableString* namestring = [NSMutableString string];
	if(user.name) [namestring appendString:user.name];
	if(user.tripcode) [namestring appendFormat:@"#%@",user.tripcode];
	if(user.securetrip) [namestring appendFormat:@"##%@",user.securetrip];

	if([namestring length]) [request setPostValue:namestring forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Name"]];
	if(user.email) [request setPostValue:user.email forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Email"]];
	if(user.password) [request setPostValue:user.password forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Password"]];

	if(subject) [request setPostValue:subject forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Subject"]];
	if(comment) [request setPostValue:comment forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Comment"]];
	if(file) {
		[request setFile:[file path] forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.File"]];
		if(spoiler) {
			NSString* spoilername,* spoilerenabled;
			if((spoilername = [[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Spoiler.Field"]) &&
			   (spoilerenabled = [[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Spoiler.Enabled"]))
				[request setPostValue:spoilerenabled forKey:spoilername];
		}
	}
	if([[CKRecipe sharedRecipe] resourceKindForURL:URL] != CK_RESOURCE_BOARD)
		[request setPostValue:[NSString stringWithFormat:@"%d",[CKUtil parseThreadID:URL]] 
					   forKey:[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Thread"]];

	[[[CKRecipe sharedRecipe] lookup:@"Poster.Fields.Extra"] enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop){
		[request setPostValue:object forKey:key];
	}];
	
	[request setPostValue:@"regist" forKey:@"mode"];

	if(captcha.verification) {
		[request setPostValue:captcha.challenge forKey:@"recaptcha_challenge_field"];
		[request setPostValue:captcha.verification forKey:@"recaptcha_response_field"];
	}
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
	NSXMLDocument* doc;
	if((*error = [CKUtil fetchXML:&doc viaRequest:request]) == CK_ERR_SUCCESS) {
		if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.Captcha" inDocument:doc])
			*error = CK_POSTERR_VERIFICATION;
		else if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.Flood" inDocument:doc])
			*error = CK_POSTERR_FLOOD;
		else if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.Disallowed" inDocument:doc])
			*error = CK_POSTERR_DISALLOWED;
		else if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.NotFound" inDocument:doc])
			*error = CK_POSTERR_NOTFOUND;
		else if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.Rejected" inDocument:doc])
			*error = CK_POSTERR_REJECTED;
		else if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.Filetype" inDocument:doc])
			*error = CK_POSTERR_FILETYPE;
		else if([[CKRecipe sharedRecipe] lookup:@"Poster.Response.Duplicate" inDocument:doc]) {
			*error = CK_POSTERR_DUPLICATE;
			return [CKPost postReferencingURL:[NSURL URLWithString:[[CKRecipe sharedRecipe] lookup:@"Poster.Response.Duplicate.URL" inDocument:doc] relativeToURL:URL]];
		}
		else {
			NSString* resboard,* redirect = [[CKRecipe sharedRecipe] lookup:@"Poster.Response.URL" inDocument:doc];
			if(redirect)
				resboard = [[CKUtil parseBoardRoot:[NSURL URLWithString:redirect relativeToURL:URL]] absoluteString];
			else resboard = [[CKUtil parseBoardRoot:URL] absoluteString];
			NSString* resthread = [[CKRecipe sharedRecipe] lookup:@"Poster.Response.Thread" inDocument:doc];
			NSString* respost = [[CKRecipe sharedRecipe] lookup:@"Poster.Response.Post" inDocument:doc];
			if(![resthread intValue]) resthread = respost;
			DLog(@"Got Board: %@",resboard);
			DLog(@"Got Thread: %@",resthread);
			DLog(@"Got Post: %@",respost);
			if(resthread && respost && resboard) {
				NSURL* resurl = [NSURL URLWithString:[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Poster.Response.Format"],resboard,resthread,respost]];
				DLog(@"URL: %@",[resurl absoluteString]);
				// 4chan will happily serve us a cached page that doesn't include our post, especially on long threads, so we can't return a populated post
				// Better not to make network-hitting decisions like that anyway.
				return [CKPost postReferencingURL:resurl];
			}
			*error = CK_ERR_UNDEFINED;
		}
	}
	return nil;
}

@end
