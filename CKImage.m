/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKImage.h - Cross-compatible wrapper around NSImage/UIImage with imageboard-specific metadata and convenience routines.
 */

#import "CKImage.h"
	#import "Common.h"

@implementation CKImage

- (id)initByReferencingURL:(NSURL*)url {
	if(self = [super init]) {
		URL = [url retain];
//		image = [[[NSImage alloc] initByReferencingURL:URL] autorelease];
		name = [[URL lastPathComponent] retain];
		timestamp = [[NSDate alloc] initWithTimeIntervalSince1970:[[name stringByMatching:@"\\d{10}"] floatValue]];
		
		DLog(@"Image URL: %@",URL);
		DLog(@"Image Name: %@",name);
		DLog(@"Image Timestamp: %@",timestamp);
	}
	return self;
}
+ (CKImage*)imageReferencingURL:(NSURL*)url { return [[[self alloc] initByReferencingURL:url] autorelease]; }

- (id)initWithContentsOfURL:(NSURL*)url {
	if((self = [self initByReferencingURL:url]) && [self load]) {
		resolution = [self.image size];
		size = [image length];
		MD5 = [[CKUtil MD5:image] retain];

		DLog(@"Image Resolution: %0.0fx%0.0f",resolution.width,resolution.height);
		DLog(@"Image Size: %u bytes",size);
		DLog(@"Image MD5: %@",MD5);

		return self;		
	}
	return nil;
}
+ (CKImage*)imageWithContentsOfURL:(NSURL*)url { return [[[self alloc] initWithContentsOfURL:url] autorelease]; }

- (id)initWithXML:(DDXMLNode*)doc {
	NSString* url;
	if((self = [super init]) && (url = [[CKRecipe sharedRecipe] lookup:@"Image/URL" inDocument:doc]) != nil) {
		URL = [[NSURL alloc] initWithString:url];
		name = [[[CKRecipe sharedRecipe] lookup:@"Image/Name" inDocument:doc] retain];
		resolution = CGSizeMake([[[CKRecipe sharedRecipe] lookup:@"Image/Width" inDocument:doc] floatValue],
						  [[[CKRecipe sharedRecipe] lookup:@"Image/Height" inDocument:doc] floatValue]);
		NSString* turl;
		if((turl = [[CKRecipe sharedRecipe] lookup:@"Image/Thumbnail" inDocument:doc]))
			thumbnail = [[CKImage alloc] initByReferencingURL:[NSURL URLWithString:turl]];
		
		if([[[CKRecipe sharedRecipe] lookup:@"Image/Measure" inDocument:doc] isEqualToString:@"MB"])
			size = [[[CKRecipe sharedRecipe] lookup:@"Image/Size" inDocument:doc] floatValue] * 1048576;
		else 
			size = [[[CKRecipe sharedRecipe] lookup:@"Image/Size" inDocument:doc] floatValue] * 1024;
		MD5 = [[[CKRecipe sharedRecipe] lookup:@"Image/MD5" inDocument:doc] retain];
		timestamp = [[NSDate alloc] initWithTimeIntervalSince1970:[[[CKRecipe sharedRecipe] lookup:@"Image/Date" inDocument:doc] doubleValue]];

		DLog(@"Image URL: %@",URL);
		DLog(@"Image Name: %@",name);
		DLog(@"Image Timestamp: %@",name);
		DLog(@"Image Resolution: %0.0fx%0.0f",resolution.width,resolution.height);
		DLog(@"Image Size: %u bytes",size);
		DLog(@"Image MD5: %@",MD5);

		return self;
	}
	return nil;
}
+ (CKImage*)imageFromXML:(DDXMLNode*)doc { return [[[self alloc] initWithXML:doc] autorelease]; }
- (void)dealloc {
	[URL release];
	[image release];
	[name release];
	[MD5 release];
	[timestamp release];
	[thumbnail release];
	[super dealloc];
}

@synthesize URL;
@synthesize name;
@synthesize size;
@synthesize MD5;
@synthesize resolution;
@synthesize timestamp;
@synthesize thumbnail;

- (void)setMetadata:(NSDictionary*)meta {
	for(NSString* key in meta) {
		if([key isEqualToString:@"Name"])
			name = [[meta objectForKey:key] retain];
		else if([key isEqualToString:@"Size"])
			size = [[meta objectForKey:key] unsignedIntegerValue];
		else if([key isEqualToString:@"Resolution"])
			resolution = [[meta objectForKey:key] CGSizeValue];
		else if([key isEqualToString:@"MD5"])
			MD5 = [[meta objectForKey:key] retain];
		else if([key isEqualToString:@"Timestamp"])
			timestamp = [[meta objectForKey:key] retain];
	}
}

- (BOOL)isLoaded { return image != nil; }
- (NSString*)MD5 {
	if(!MD5) [self load];
	return MD5;
}
- (UIImage*)image {	return [[[UIImage alloc] initWithData:image] autorelease]; }
- (NSData*)data { 
	[self load];
	return [image copy];
}
- (BOOL)load { 
	if(!image)
		image = [[NSURLConnection sendSynchronousRequest:[NSMutableURLRequest requestWithURL:URL] returningResponse:nil error:nil] retain];
	return self.isLoaded;
}
- (NSString*)formattedSize {
	return size > 1048576 ? [NSString stringWithFormat:@"%.2f MB",size/1048576.0] : [NSString stringWithFormat:@"%.2f KB",size/1024.0];
}
- (NSString*)formattedResolution {
	return [NSString stringWithFormat:@"%0.0fx%0.0f",resolution.width,resolution.height];
}
- (NSString*)formattedTimestamp {
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Dates/Format"]];
	return [formatter stringFromDate:timestamp];
}
- (NSString*)description {
	return [NSString stringWithFormat:@"%cFile : %@-(%@, %@%@, %@)",
			NSNewlineCharacter,[URL lastPathComponent],self.formattedSize,self.formattedResolution,
			name ? [NSString stringWithFormat:@", %@",name] : @"",self.formattedTimestamp];
}

- (DDXMLNode*)XMLRepresentation {
	/*
	 * Images are stored in local thread dirs, left to the client application to determine the actual directory structure
	 * Archiving apps should reference images by hash to save space
	 * [MD5 stringByAppendingPathExtension:[name pathExtension]]
	 * Apparently no imageboard software is smart enough to figure this out
	 * Path stuff needs to be figured out... May be convoluted enough to warrant a CKArchive class to manage all this
	 * This is all likely to change.
	 */
	[self load];
	NSString* thumbpath = [NSString pathWithComponents:[NSArray arrayWithObjects:@"image",@"thumbs",
							[[name stringByDeletingPathExtension] stringByAppendingPathExtension:[thumbnail.name pathExtension]],nil]];
	NSString* imgpath = [NSString pathWithComponents:[NSArray arrayWithObjects:@"image",name,nil]];

	DDXMLNode* xmlthumb = [DDXMLElement elementWithName:@"img" children:nil
											 attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"src" stringValue:thumbpath]]];

	// Need some way to signal whether we intend to store the image, unless the href attr can be removed from the document later
	DDXMLNode* xmlimage = [DDXMLElement elementWithName:@"a"
											   children:[NSArray arrayWithObject:xmlthumb]
											 attributes:[NSArray arrayWithObjects:
														 [DDXMLNode attributeWithName:@"href" stringValue:imgpath],
														 [DDXMLNode attributeWithName:@"class" stringValue:@"image"],
														 [DDXMLNode attributeWithName:@"data-timestamp" stringValue:self.formattedTimestamp],
														 [DDXMLNode attributeWithName:@"data-width" stringValue:
														  [NSString stringWithFormat:@"%0.0f",self.resolution.width]],
														 [DDXMLNode attributeWithName:@"data-height" stringValue:
														  [NSString stringWithFormat:@"%0.0f",self.resolution.height]],
														 [DDXMLNode attributeWithName:@"data-size" 
																		  stringValue:[NSString stringWithFormat:@"%d",size]],
														 [DDXMLNode attributeWithName:@"data-md5" stringValue:MD5],
														 [DDXMLNode attributeWithName:@"data-name" stringValue:name],
														 [DDXMLNode attributeWithName:@"data-origin" stringValue:[URL absoluteString]],nil]];
	
	DDXMLNode* xmlfile = [DDXMLElement elementWithName:@"a"
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:[imgpath lastPathComponent]]]
											attributes:[NSArray arrayWithObjects:
														[DDXMLNode attributeWithName:@"href" stringValue:imgpath],
														[DDXMLNode attributeWithName:@"class" stringValue:@"image-path"],nil]];

	DDXMLNode* xmlsize = [DDXMLElement elementWithName:@"span"
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:self.formattedSize]]
											attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"image-size"]]];

	DDXMLNode* xmlres = [DDXMLElement elementWithName:@"span"
											 children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:self.formattedResolution]]
										   attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" 
																								stringValue:@"image-resolution"]]];
	
	DDXMLNode* xmlname = [DDXMLElement elementWithName:@"span"
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:name]]
											attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"image-name"]]];
	
	DDXMLNode* xmltime = [DDXMLElement elementWithName:@"span"
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:self.formattedTimestamp]]
											attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class"
																								 stringValue:@"image-timestamp"]]];
	

	DDXMLNode* xmlcomma = [DDXMLNode textWithStringValue:@", "];
	DDXMLNode* xmldescription = [DDXMLElement elementWithName:@"span"
													 children:[NSArray arrayWithObjects:[DDXMLNode textWithStringValue:@"File: "],
																						xmlfile,[DDXMLNode textWithStringValue:@" - ("],
																						xmlsize,xmlcomma,xmlres,xmlcomma,xmlname,xmlcomma,xmltime,
																						[DDXMLNode textWithStringValue:@")"],nil]
											 attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" 
																								  stringValue:@"image-description"]]];
	return [DDXMLElement elementWithName:@"div"
								children:[NSArray arrayWithObjects:xmldescription,xmlimage,nil]
							  attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"file"]]];

}

- (NSUInteger)hash { return [image hash]; }

@end
