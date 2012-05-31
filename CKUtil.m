/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKUtil.m - Utility string/URL/network methods. Globally included.
 */

#import <CommonCrypto/CommonDigest.h>
#import "NSData+Base64/NSData+Base64.h"
#import "CKRecipe.h"
#import "CKUtil.h"

@implementation CKUtil

// The bundle info dictionary is busted
+ (NSString*)version {
	return [NSString stringWithFormat:@"%d.%d.%d%@-%@",CK_VERSION_MAJOR,CK_VERSION_MINOR,CK_VERSION_MICRO,CK_VERSION_TAG,CK_VERSION_OS];
}
+ (NSString*)describeError:(int)errnum {
	switch(errnum) {
		case CK_ERR_UNDEFINED:          return @"Unknown error";
		// Document fetch errors
		case CK_ERR_SUCCESS:            return @"Operation succeeded";
		case CK_ERR_NETWORK:            return @"Resource not reachable";
		case CK_ERR_CHECKSUM:           return @"Resource failed checksum verification";
		case CK_ERR_NOTFOUND:           return @"Resource not found";
		case CK_ERR_PARSER:             return @"Document could not be parsed";
		case CK_ERR_UNSUPPORTED:        return @"Unsupported board software";
		case CK_ERR_BANNED:             return @"You are banned";
		case CK_ERR_REDIRECT:           return @"Bad redirection";
		// Common post errors
		case CK_POSTERR_FLOOD:          return @"Flood detected";
		case CK_POSTERR_VERIFICATION:   return @"CAPTCHA verification failed";
		case CK_POSTERR_DUPLICATE:      return @"Duplicate image detected";
		case CK_POSTERR_NOTFOUND:       return @"Thread not found";
		case CK_POSTERR_DISALLOWED:     return @"Comment disallowed";
		case CK_POSTERR_REJECTED:       return @"File rejected";
		case CK_POSTERR_FILETYPE:       return @"Filetype mismatch";
		case CK_POSTERR_FAILEDUPLOAD:   return @"Upload failed";
		default:                        return nil;
	}
}

+ (int)parsePostID:(NSURL*)URL { 
	int res = [[CKRecipe sharedRecipe] resourceKindForURL:URL];
	switch(res) {
		case CK_RESOURCE_POST:
			return [[[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.Post"] capture:1L] integerValue];
		case CK_RESOURCE_THREAD:
			return [[[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.Thread"] capture:1L] integerValue];
		default: return -1;
	}	
}
+ (int)parseThreadID:(NSURL*)URL { 
	int res = [[CKRecipe sharedRecipe] resourceKindForURL:URL];
	if(res != CK_RESOURCE_POST && res != CK_RESOURCE_THREAD) return -1;
	return [[[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.Thread"] capture:1L] integerValue]; 
}
+ (int)parsePage:(NSURL*)URL {
	if([[CKRecipe sharedRecipe] resourceKindForURL:URL] != CK_RESOURCE_BOARD) return -1;
	return [[[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.Page"] capture:1L] integerValue]; 
}
+ (NSString*)parseBoard:(NSURL*)URL { 
	if([[CKRecipe sharedRecipe] resourceKindForURL:URL] == CK_RESOURCE_UNDEFINED) return nil;
	return [[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.Board"] capture:1L]; 
}
+ (NSURL*)parseBoardRoot:(NSURL*)URL { 
	if([[CKRecipe sharedRecipe] resourceKindForURL:URL] == CK_RESOURCE_UNDEFINED) return nil;
	NSString* root;
	if((root = [[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.BoardRoot"] capture:1L]))
		return [NSURL URLWithString:root];
	return nil;
}
+ (NSURL*)URLByDeletingFragment:(NSURL*)URL { 
	return [NSURL URLWithString:[[URL absoluteString] stringByMatching:@"[^#]+"]]; 
}

+ (int)fetchXML:(NSXMLDocument**)doc viaRequest:(ASIHTTPRequest*)request throughProxy:(NSURL*)proxy allowedRedirects:(NSUInteger)redirects {
	if(!doc) return CK_ERR_UNDEFINED;
	*doc = nil;
	[CKUtil setProxy:proxy onRequest:request];
	[request startSynchronous];
	int error = [CKUtil validateResponse:request];
	if(error != CK_ERR_SUCCESS)
		return error;
	if(!request.contentLength)
		return CK_ERR_UNDEFINED;
		
	//*doc = [[[NSXMLDocument alloc] initWithData:[request responseData] options:NSXMLDocumentTidyHTML error:NULL] autorelease];
	//Dirty trick to work around a bug in the outdated version of libxml2 used by NSXMLDocument
	NSString* response = [request responseString];
	if(!response)
		response = [[[NSString alloc] initWithBytes:[[request responseData] bytes] length:[[request responseData] length] encoding:NSASCIIStringEncoding] autorelease];
	if(!(*doc = [[NSXMLDocument alloc] initWithXMLString:[response stringByReplacingOccurrencesOfString:@"<'+'\\/script>" withString:@"</script>"] 
	                                             options:NSXMLDocumentTidyHTML error:NULL]))
		return CK_ERR_PARSER;
	[*doc setURI:[[request url] absoluteString]];

	id redirect; // each object along the way to check a redirect is only needed as an argument to the next so re-use the same pointer
	if(!(redirects && [(redirect = [*doc nodesForXPath:@"/html/head/meta[@http-equiv=\"refresh\"]/@content" error:NULL]) count])) {
		[*doc autorelease];
		if([[CKRecipe sharedRecipe] certainty] == CK_RECIPE_NOMATCH && [[CKRecipe sharedRecipe] detectBoardSoftware:*doc] <= 0) {
			DLog(@"Unsupported board type");
			return CK_ERR_UNSUPPORTED;
		}
		if([CKUtil detectBan:*doc]) {
			DLog(@"Banned!");
			return CK_ERR_BANNED;
		}
		return CK_ERR_SUCCESS;
	}
	
	if(!((redirect = [[[redirect objectAtIndex:0] stringValue] stringByMatching:@"(?i)\\d+;\\s*url=(.+)" capture:1L]) &&
	     (redirect = [NSURL URLWithString:redirect relativeToURL:[request url]]))) {
		[*doc autorelease];
		return CK_ERR_REDIRECT;
	}
	[*doc release];
	return [CKUtil fetchXML:doc fromURL:redirect throughProxy:proxy allowedRedirects:redirects-1];
}
+ (int)fetchXML:(NSXMLDocument**)doc viaRequest:(ASIHTTPRequest*)request allowedRedirects:(NSUInteger)redirects {
	return [CKUtil fetchXML:doc viaRequest:request throughProxy:[[NSUserDefaults standardUserDefaults] URLForKey:@"CKProxySetting"]  allowedRedirects:redirects];
}
+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL throughProxy:(NSURL*)proxy allowedRedirects:(NSUInteger)redirects {
	ASIHTTPRequest* fetch = [ASIHTTPRequest requestWithURL:URL];
	return [CKUtil fetchXML:doc viaRequest:fetch throughProxy:proxy allowedRedirects:redirects];
}
+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL {
	return [CKUtil fetchXML:doc fromURL:URL throughProxy:[[NSUserDefaults standardUserDefaults] URLForKey:@"CKProxySetting"] allowedRedirects:5 /*ASI default*/];
}

+ (int)validateResponse:(ASIHTTPRequest*)response {
	if([response error]) {
		DLog(@"%@",[[response error] localizedDescription]);
		return CK_ERR_NETWORK;
	}
	if([response responseStatusCode] >= 400) {
		DLog(@"%@",[response responseStatusMessage]);
		return [response responseStatusCode];
	}
	return CK_ERR_SUCCESS;
}

+ (BOOL)detectBan:(NSXMLDocument*)doc {
	if([[CKRecipe sharedRecipe] lookup:@"Special.Ban.Identifier" inDocument:doc]) {
		DLog(@"Banned from board: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.Board" inDocument:doc]);
		DLog(@"Banned with reason: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.Reason" inDocument:doc]);
		DLog(@"Banned IP: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.IP" inDocument:doc]);
		DLog(@"Banned name: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.Name" inDocument:doc]);
		DLog(@"Banned from %@ to %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.From" inDocument:doc],
		                             [[CKRecipe sharedRecipe] lookup:@"Special.Ban.To" inDocument:doc]);
		return YES;
	}
	return NO;
}
// the adjacency of these methods is in no way suggestive
+ (void)setProxy:(NSURL*)proxy onRequest:(ASIHTTPRequest*)request {
	if(!proxy) return;
	[request setTimeOutSeconds:CK_PROXY_TIMEOUT]; // Since it's a proxy, latency may be much higher
	[request setProxyHost:[proxy host]];
	[request setProxyPort:[[proxy port] intValue]];
	if([[proxy scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame)
		[request setProxyType:(NSString*)kCFProxyTypeHTTP];
	else if([[proxy scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame)
		[request setProxyType:(NSString*)kCFProxyTypeHTTPS];
	else if([[proxy scheme] caseInsensitiveCompare:@"socks"] == NSOrderedSame)
		[request setProxyType:(NSString*)kCFProxyTypeSOCKS];
	DLog(@"Using proxy %@://%@:%d",[request proxyType],[request proxyHost],[request proxyPort]);
}

+ (BOOL)checkProxySanity:(NSURL*)proxy destination:(NSURL*)url {
	ASIHTTPRequest* head = [[ASIHTTPRequest requestWithURL:url] HEADRequest];
	[CKUtil setProxy:proxy onRequest:head];
	[head setTimeOutSeconds:10]; // plenty for a HEAD request
	[head startSynchronous];
	return [CKUtil validateResponse:head] == CK_ERR_SUCCESS && [[head url] isEqualTo:[url absoluteURL]];
}

+ (NSString*)generatePassword {
	char pass[8];
	for(int i = 0; i < 8; i++)
		pass[i] = arc4random()*94ULL/4294967296ULL+33;
	return [[[NSString alloc] initWithBytes:pass length:8 encoding:NSASCIIStringEncoding] autorelease];
}
+ (NSString*)MD5:(NSData*)data {
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5([data bytes],[data length],result);
	return [[NSData dataWithBytes:result length:CC_MD5_DIGEST_LENGTH] base64EncodedString];
}

@end
