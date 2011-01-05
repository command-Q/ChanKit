/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKUtil.m - Utility string/URL/network methods. Globally included.
 */

#import "CKUtil.h"

@implementation CKUtil

+ (int)parseThreadID:(NSURL*)URL { 
	if([[CKRecipe sharedRecipe] certainty] == CK_RECIPE_NOMATCH && [[CKRecipe sharedRecipe] detectSite:URL] <= 0) return -1;
	return [[[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Thread/ID"] capture:1L] intValue]; 
}
+ (NSString*)parseBoard:(NSURL*)URL { 
	if([[CKRecipe sharedRecipe] certainty] == CK_RECIPE_NOMATCH && [[CKRecipe sharedRecipe] detectSite:URL] <= 0) return nil;
	return [[URL absoluteString] stringByMatching:[[CKRecipe sharedRecipe] lookup:@"Board/Name"] capture:1L]; 
}
+ (NSString*)parseBoardFromString:(NSString*)URL { return [self parseBoard:[NSURL URLWithString:URL]]; }

+ (NSURL*)URLByDeletingFragment:(NSURL*)URL { 
	return [NSURL URLWithString:[[URL absoluteString] stringByMatching:@"[^#]+"]]; 
}
+ (NSURL*)changePost:(NSURL*)original toPost:(int)idno{
	return [NSURL URLWithString:[NSString stringWithFormat:@"%@#%d",[self URLByDeletingFragment:original],idno]]; 
}

+ (int)fetchXML:(NSXMLDocument**)doc fromURL:(NSURL*)URL{
	if(!(*doc = [[[NSXMLDocument alloc] initWithContentsOfURL:URL options:NSXMLDocumentTidyHTML error:NULL] autorelease])) {
		DLog(@"404");
		return CK_ERR_NOTFOUND;		
	}
	if([[CKRecipe sharedRecipe] certainty] == CK_RECIPE_NOMATCH && [[CKRecipe sharedRecipe] detectBoardSoftware:*doc] <= 0) {
		DLog(@"Unsupported board type");
		return CK_ERR_UNSUPPORTED;
	}
	return 0;
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
	NSMutableString* MD5 = [[NSMutableString alloc] init];
	unsigned char* result = malloc(sizeof(unsigned char)*CC_MD5_DIGEST_LENGTH);
	CC_MD5([data bytes],[data length],result);
	for(int i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
		[MD5 appendFormat:@"%02X",result[i]];
	return MD5;
}
@end
