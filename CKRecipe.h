/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2010-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKRecipe.h - Imageboard software definition singleton.
 */

@interface CKRecipe : NSObject {
	NSDictionary* recipe;
	int certainty;
}
@property(nonatomic,readonly) int certainty;
@property(nonatomic,readonly) NSDictionary* recipe;

+ (CKRecipe*)sharedRecipe;

- (NSDictionary*)recipeNamed:(NSString*)name;
- (NSDictionary*)recipeFile:(NSString*)path;
- (int)detectSite:(NSURL*)URL;
- (int)detectBoardSoftware:(NSXMLDocument*)doc;

- (NSDictionary*)recipe;

- (id)lookup:(NSString*)keyPath;
- (NSString*)lookup:(NSString*)keyPath inDocument:(NSXMLNode*)doc;
- (NSString*)lookup:(NSString*)keyPath inDocument:(NSXMLNode*)doc test:(id)test;

- (NSArray*)supportedSites;
- (NSArray*)supportedSoftware;
- (NSURL*)URLForSite:(NSString*)sitename;
- (NSURL*)matchSite:(NSString*)site resourceKind:(int*)kind;
- (int)resourceKindForURL:(NSURL*)URL;
@end
