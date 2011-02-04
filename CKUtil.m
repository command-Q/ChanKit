/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2009-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKUtil.m - Utility string/URL/network methods. Globally included.
 */

#import <CommonCrypto/CommonDigest.h>
#import "NSData+Base64/NSData+Base64.h"
#import "CKRecipe.h"
#import "CKUtil.h"

@implementation CKUtil

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
+ (NSString*)parseBoardFromString:(NSString*)URL { return [self parseBoard:[NSURL URLWithString:URL]]; }
+ (NSString*)parseBoardRoot:(NSURL*)URL { 
	if([[CKRecipe sharedRecipe] resourceKindForURL:URL] == CK_RESOURCE_UNDEFINED) return nil;
	return [[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Definitions.URL.BoardRoot"] capture:1L]; 
}
+ (NSURL*)URLByDeletingFragment:(NSURL*)URL { 
	return [NSURL URLWithString:[[URL absoluteString] stringByMatching:@"[^#]+"]]; 
}

+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL throughProxy:(NSURL*)proxy {
	ASIHTTPRequest* fetch = [ASIHTTPRequest requestWithURL:URL];
	[CKUtil setProxy:proxy onRequest:&fetch];
	[fetch startSynchronous];
	int error;
	if((error = [CKUtil validateResponse:fetch]) != CK_ERR_SUCCESS)
		return error;
	*doc = [[[NSXMLDocument alloc] initWithData:[fetch responseData] options:NSXMLDocumentTidyHTML error:NULL] autorelease];
	[*doc setURI:[[fetch url] absoluteString]];
	if([[CKRecipe sharedRecipe] certainty] == CK_RECIPE_NOMATCH && [[CKRecipe sharedRecipe] detectBoardSoftware:*doc] <= 0) {
		DLog(@"Unsupported board type");
		return CK_ERR_UNSUPPORTED;
	}
	if([CKUtil checkBan:*doc]) {
		DLog(@"Banned!");
		return CK_ERR_BANNED;
	}
	return CK_ERR_SUCCESS;	
}
+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL {
	return [CKUtil fetchXML:doc fromURL:URL throughProxy:[[NSUserDefaults standardUserDefaults] URLForKey:@"CKProxySetting"]]; // Very bad!
}

+ (BOOL)checkBan:(NSXMLDocument*)doc { 
	if([[CKRecipe sharedRecipe] lookup:@"Special.Ban.Identifier" inDocument:doc]) {
		DLog(@"Banned from board: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.Board" inDocument:doc]);
		DLog(@"Banned with reason: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.Reason" inDocument:doc]);
		DLog(@"Banned IP: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.IP" inDocument:doc]);
		DLog(@"Banned name: %@",[[CKRecipe sharedRecipe] lookup:@"Special.Ban.Name" inDocument:doc]);
		DLog(@"Banned from %@ to %@",	[[CKRecipe sharedRecipe] lookup:@"Special.Ban.From" inDocument:doc],
										[[CKRecipe sharedRecipe] lookup:@"Special.Ban.To" inDocument:doc]);
		return YES;
	}
	return NO;
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

// The bunlde info dictionary is busted
+ (NSString*)version {
	return [NSString stringWithFormat:@"%d.%d.%d%@-%@",CK_VERSION_MAJOR,CK_VERSION_MINOR,CK_VERSION_MICRO,CK_VERSION_TAG,CK_VERSION_OS];
}

+ (NSString*)generatePassword {
	NSString* alphanum = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString* pass = [NSMutableString stringWithCapacity:8];
	srand(time(NULL)); //Not really worried about entropy here
	for(int i = 0; i < 8; i++)
		[pass appendFormat:@"%c",[alphanum characterAtIndex:rand()%[alphanum length]]];
	return pass;
}

+ (NSString*)MD5:(NSData*)data {
	unsigned char result[CC_MD5_DIGEST_LENGTH];
	CC_MD5([data bytes],[data length],result);
	return [[NSData dataWithBytes:result length:CC_MD5_DIGEST_LENGTH] base64EncodedString];
}

+ (void)setProxy:(NSURL*)proxy onRequest:(ASIHTTPRequest**)request {
	if(!proxy) return;
	[*request setTimeOutSeconds:CK_PROXY_TIMEOUT]; // Since it's a proxy, latency may be much higher
	[*request setProxyHost:[proxy host]];
	[*request setProxyPort:[[proxy port] intValue]];
	if([[proxy scheme] caseInsensitiveCompare:@"http"] == NSOrderedSame)
		[*request setProxyType:(NSString*)kCFProxyTypeHTTP];
	else if([[proxy scheme] caseInsensitiveCompare:@"https"] == NSOrderedSame)
		[*request setProxyType:(NSString*)kCFProxyTypeHTTPS];
	else if([[proxy scheme] caseInsensitiveCompare:@"socks"] == NSOrderedSame)
		[*request setProxyType:(NSString*)kCFProxyTypeSOCKS];
	DLog(@"Using proxy %@://%@:%d",[*request proxyType],[*request proxyHost],[*request proxyPort]);
}
@end
