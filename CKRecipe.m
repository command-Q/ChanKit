/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2010-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKRecipe.m - Imageboard software definition singleton.
 */

#import "CKRecipe.h"

static CKRecipe* sharedInstance = nil;

@implementation CKRecipe

+ (CKRecipe*)sharedRecipe {
	@synchronized(self) {
		if(!sharedInstance)
			sharedInstance = [[self alloc] init];
	}
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
	@synchronized(self) {
		if(!sharedInstance) {
			sharedInstance = [super allocWithZone:zone];
			return sharedInstance;
		}
	}
	return nil;
}

- (id)copyWithZone:(NSZone *)zone { return self; }
- (id)retain { return self; }
- (oneway void)release {}
- (id)autorelease { return self; }
- (NSUInteger)retainCount { return NSUIntegerMax; }

- (id)init {
    @synchronized([self class]) {
        if(!sharedInstance)
			sharedInstance = self = [super init];
    }
    return sharedInstance;
}

- (NSDictionary*)recipeNamed:(NSString*)name {
	@synchronized(self) {
		return [self recipeFile:[[NSBundle bundleForClass:[self class]] pathForResource:name ofType:@"plist" inDirectory:@"Recipes"]];
	}
}

- (NSDictionary*)recipeFile:(NSString*)path {
	@synchronized(self) {
		if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
			certainty = CK_RECIPE_MANUAL;
			[recipe release];
			return recipe = [[NSDictionary dictionaryWithContentsOfFile:path] retain];
		}
		return nil;
	}
}

- (int)certainty { @synchronized(self) { return certainty; }}

- (int)detectSite:(NSURL*)URL {
	@synchronized(self) {
		NSArray* recipes = [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"plist" inDirectory:@"Recipes"];
		[recipe release];
		for(NSString* path in recipes) {
			recipe = [NSDictionary dictionaryWithContentsOfFile:path];
			for(NSDictionary* site in [self lookup:@"Support.Sites"]) {
				for(NSString* url in [site objectForKey:@"URLs"])
					if([url isEqualToString:[URL host]]) {
						certainty = CK_RECIPE_URLMATCH;
						DLog(@"Using %@",path);
						[recipe retain];
						return CK_DETECTION_URL;
					}
				for(NSString* regex in [site objectForKey:@"Regex"])
					if([[URL absoluteString] isMatchedByRegex:regex]) {
						certainty = CK_RECIPE_URLMATCH;
						DLog(@"Using %@",path);
						[recipe retain];
						return CK_DETECTION_URL;
					}
			}
		}
		recipe = nil;
		return CK_DETECTION_FAILED;
	}
}

- (NSURL*)matchSite:(NSString*)site resourceKind:(int*)kind {
	@synchronized(self) {
		int type = CK_RESOURCE_UNDEFINED;
		NSString* result;
		[recipe release];
		for(NSString* path in [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"plist" inDirectory:@"Recipes"]) {
			recipe = [NSDictionary dictionaryWithContentsOfFile:path];
			for(NSDictionary* sitesupport in [self lookup:@"Support.Sites"]) {
				 if([(result = [site stringByMatching:[NSString stringWithFormat:@".*(%@).*",[sitesupport valueForKeyPath:@"Regex.Image"]] capture:1L]) length])
					 type = CK_RESOURCE_IMAGE;
				 else if([(result = [site stringByMatching:[NSString stringWithFormat:@".*(%@).*",[sitesupport valueForKeyPath:@"Regex.Post"]] capture:1L]) length])
					 type = CK_RESOURCE_POST;
				 else if([(result = [site stringByMatching:[NSString stringWithFormat:@".*(%@).*",[sitesupport valueForKeyPath:@"Regex.Thread"]] capture:1L]) length])
					 type = CK_RESOURCE_THREAD;
				 else if([(result = [site stringByMatching:[NSString stringWithFormat:@".*(%@).*",[sitesupport valueForKeyPath:@"Regex.Board"]] capture:1L]) length])
					 type = CK_RESOURCE_BOARD;
				if(type != CK_RESOURCE_UNDEFINED) break;
			}
			if(type != CK_RESOURCE_UNDEFINED) break;
		}
		if(kind) *kind = type;
		[recipe retain];
		if(type != CK_RESOURCE_UNDEFINED) return [NSURL URLWithString:result];
		return nil;
	}
}

- (int)detectBoardSoftware:(NSXMLDocument*)doc {
	@synchronized(self) {
		if(!doc) return CK_DETECTION_COULDNOTPROCEED;
		if([self detectSite:[NSURL URLWithString:[doc URI]]])
			return CK_DETECTION_URL;
		NSArray* recipes = [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"plist" inDirectory:@"Recipes"];
		[recipe release];
		for(NSString* path in recipes) {
			recipe = [NSDictionary dictionaryWithContentsOfFile:path];
			certainty = CK_RECIPE_PRELIMINARY;
			if([[self lookup:@"Support.Title"] caseInsensitiveCompare:[self lookup:@"Support.Software.Title" inDocument:doc]] == NSOrderedSame) {
				NSArray* versions = [self lookup:@"Support.Versions"];
				if(versions && ![versions containsObject:[self lookup:@"Support.Software.Version" inDocument:doc]])
					continue;
				certainty = CK_RECIPE_XMLMATCH;
				DLog(@"Using %@",path);
				[recipe retain];
				return CK_DETECTION_TITLE;
			}
		}
		for(NSString* path in recipes) {
			recipe = [NSDictionary dictionaryWithContentsOfFile:path];
			if([self lookup:@"Support.Identifier" inDocument:doc]) {
				certainty = CK_RECIPE_XMLMATCH;
				DLog(@"Using %@",path);
				[recipe retain];
				return CK_DETECTION_FUZZY;
			}
		}
		recipe = nil;
		return CK_DETECTION_FAILED;
	}
}

- (NSDictionary*)recipe {
	@synchronized(self) {
		return recipe;
	}
}

- (id)lookupKeys:(NSArray*)keys inDictionary:(NSDictionary*)dict {
	@synchronized(self) {
		if(!dict) return nil;
		if([keys count] == 1)
			return [dict objectForKey:[keys objectAtIndex:0]];
		return [self lookupKeys:[keys subarrayWithRange:NSMakeRange(1,[keys count]-1)]
		           inDictionary:[dict objectForKey:[keys objectAtIndex:0]]];
	}
}
- (id)lookup:(NSString*)keyPath { @synchronized(self) { return [recipe valueForKeyPath:keyPath]; }}
- (NSString*)lookup:(NSString*)keyPath inDocument:(NSXMLNode*)doc { @synchronized(self) { return [self lookup:keyPath inDocument:doc test:nil]; }}
- (NSString*)lookup:(NSString*)keyPath inDocument:(NSXMLNode*)doc test:(id)test {
	@synchronized(self) {
		NSDictionary* lookup = nil;
		NSArray* paths,* nodes = nil;

		if(!doc || (certainty == CK_RECIPE_NOMATCH && [self detectBoardSoftware:[doc rootDocument]] == CK_DETECTION_FAILED)) return nil;

		id result = [self lookup:keyPath];
		if([result isKindOfClass:[NSDictionary class]]) {
			lookup = [NSDictionary dictionaryWithDictionary:result];
			result = [lookup objectForKey:@"Path"];
		}
		if([result isKindOfClass:[NSString class]])
			paths = [NSArray arrayWithObject:[NSString stringWithString:result]];
		else if([result isKindOfClass:[NSArray class]])
			paths = [NSArray arrayWithArray:result];
		else return nil;

		for(NSString* path in paths) {
			if(test) nodes = [doc nodesForXPath:[NSString stringWithFormat:path,test] error:NULL];
			else     nodes = [doc nodesForXPath:path error:NULL];
			if([nodes count]) break;
		}
		if(![nodes count]) return nil;

		NSString* regex,* string;
		NSString* data = [NSString string];
		for(NSXMLElement* node in nodes) {
			string = [node stringValue];
			if(lookup && (regex = [lookup objectForKey:@"NodeRegex"])) string = [string stringByMatching:regex capture:1L];
			string = [string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			if([string length]) data = [data stringByAppendingFormat:@"%@%c",string,NSNewlineCharacter];
		}
		if(lookup && (regex = [lookup objectForKey:@"Regex"])) data = [data stringByMatching:regex capture:1L];
		data = [data stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
		if([data length]) return data;
		return nil;
	}
}

- (NSArray*)supportedSites {
	@synchronized(self) {
		NSMutableArray* sites = [NSMutableArray array];
		for(NSString* path in [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"plist" inDirectory:@"Recipes"])
			for(NSDictionary* site in [[NSDictionary dictionaryWithContentsOfFile:path] valueForKeyPath:@"Support.Sites"])
				[sites addObject:[site objectForKey:@"Name"]];
		return sites;
	}
}
- (NSArray*)supportedSoftware {
	@synchronized(self) {
		NSMutableArray* sw = [NSMutableArray array];
		for(NSString* path in [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"plist" inDirectory:@"Recipes"])
			[sw addObject:[[NSDictionary dictionaryWithContentsOfFile:path] valueForKeyPath:@"Support.Title"]];
		return sw;
	}
}

// sitename must be part of the supported sites array of a recipe
- (NSURL*)URLForSite:(NSString*)sitename {
	@synchronized(self) {
		for(NSString* path in [[NSBundle bundleForClass:[self class]] pathsForResourcesOfType:@"plist" inDirectory:@"Recipes"]) {
			NSArray* site = [[NSDictionary dictionaryWithContentsOfFile:path] valueForKeyPath:@"Support.Sites"];
			NSUInteger i = [site indexOfObjectPassingTest:^(id dict, NSUInteger idx, BOOL *stop) {
				return *stop = [sitename isEqualToString:[dict objectForKey:@"Name"]];
			}];
			if(i != NSNotFound)
				return [NSURL URLWithString:[[site objectAtIndex:i] objectForKey:@"Home"]];
		}
		return nil;
	}
}

- (int)resourceKindForURL:(NSURL*)URL {
	@synchronized(self) {
		if(certainty == CK_RECIPE_NOMATCH) [self detectSite:URL];
		__block int res = CK_RESOURCE_UNDEFINED;
		NSString* absURL = [URL absoluteString];
		[[recipe valueForKeyPath:@"Support.Sites"] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
			if([absURL isMatchedByRegex:[obj valueForKeyPath:@"Regex.Image"]])
				res = CK_RESOURCE_IMAGE;
			else if([absURL isMatchedByRegex:[obj valueForKeyPath:@"Regex.Post"]])
				res = CK_RESOURCE_POST;
			else if([absURL isMatchedByRegex:[obj valueForKeyPath:@"Regex.Thread"]])
				res = CK_RESOURCE_THREAD;
			else if([absURL isMatchedByRegex:[obj valueForKeyPath:@"Regex.Board"]])
				res = CK_RESOURCE_BOARD;
			*stop = res != CK_RESOURCE_UNDEFINED;
		}];
		return res;
	}
}

@end
