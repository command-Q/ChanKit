/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * CKImage.h - Cross-compatible wrapper around NSImage/UIImage with imageboard-specific metadata and convenience routines.
 */

#import "CKImage.h"

@implementation CKImage

- (id)initByReferencingURL:(NSURL*)url {
	if((self = [super init])) {
		URL = [url retain];
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
	if((self = [self initByReferencingURL:url]) && [self load] == CK_ERR_SUCCESS) {
		resolution = [self.image size];
		size = [image length];
		DLog(@"Image Resolution: %0.0fx%0.0f",resolution.width,resolution.height);
		DLog(@"Image Size: %u bytes",size);
		return self;		
	}
	return nil;
}
+ (CKImage*)imageWithContentsOfURL:(NSURL*)url { return [[[self alloc] initWithContentsOfURL:url] autorelease]; }

- (id)initWithXML:(NSXMLNode*)doc {
	NSString* url;
	if((self = [super init]) && (url = [[CKRecipe sharedRecipe] lookup:@"Image.URL" inDocument:doc]) != nil) {
		URL = [[NSURL alloc] initWithString:url relativeToURL:[NSURL URLWithString:[doc URI]]];
		name = [[[CKRecipe sharedRecipe] lookup:@"Image.Name" inDocument:doc] retain];
		resolution = NSMakeSize([[[CKRecipe sharedRecipe] lookup:@"Image.Width" inDocument:doc] floatValue],
						  [[[CKRecipe sharedRecipe] lookup:@"Image.Height" inDocument:doc] floatValue]);
		NSString* turl;
		if((turl = [[CKRecipe sharedRecipe] lookup:@"Image.Thumbnail" inDocument:doc]))
			thumbnail = [[CKImage alloc] initByReferencingURL:[NSURL URLWithString:turl relativeToURL:URL]];
		size = [[[CKRecipe sharedRecipe] lookup:@"Image.Size" inDocument:doc] floatValue] * 1024;
		if([[[CKRecipe sharedRecipe] lookup:@"Image.Measure" inDocument:doc] isEqualToString:@"MB"])
			size *= 1024;
		MD5 = [[[CKRecipe sharedRecipe] lookup:@"Image.MD5" inDocument:doc] retain];
		timestamp = [[NSDate alloc] initWithTimeIntervalSince1970:[[[CKRecipe sharedRecipe] lookup:@"Image.Date" inDocument:doc] doubleValue]];
		spoiler = (BOOL)[[CKRecipe sharedRecipe] lookup:@"Image.Spoiler" inDocument:doc];
		
		DLog(@"Image URL: %@",URL);
		DLog(@"Image Name: %@",name);
		DLog(@"Image Timestamp: %@",name);
		DLog(@"Image Resolution: %0.0fx%0.0f",resolution.width,resolution.height);
		DLog(@"Image Size: %u bytes",size);
		DLog(@"Image MD5: %@",MD5);
		DLog(@"Image is spoiler: %d",spoiler);

		return self;
	}
	return nil;
}
+ (CKImage*)imageFromXML:(NSXMLNode*)doc { return [[[self alloc] initWithXML:doc] autorelease]; }

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
@synthesize spoiler;
@synthesize verified;

- (void)setMetadata:(NSDictionary*)meta {
	for(NSString* key in meta) {
		if([key isEqualToString:@"Name"])
			name = [[meta objectForKey:key] retain];
		else if([key isEqualToString:@"Size"])
			size = [[meta objectForKey:key] unsignedIntegerValue];
		else if([key isEqualToString:@"Resolution"])
			resolution = [[meta objectForKey:key] sizeValue];
		else if([key isEqualToString:@"MD5"])
			MD5 = [[meta objectForKey:key] retain];
		else if([key isEqualToString:@"Timestamp"])
			timestamp = [[meta objectForKey:key] retain];
		else if([key isEqualToString:@"Spoiler"])
			spoiler = [[meta objectForKey:key] boolValue];
	}
}

- (BOOL)isLoaded { return image != nil; }
- (NSString*)MD5 {
	if(MD5 || [self load] == CK_ERR_SUCCESS)
		return [MD5 copy];
	return nil;
}
- (NSImage*)image {	return [[[NSImage alloc] initWithData:image] autorelease]; }
- (NSData*)data { 
	[self load];
	return image;
}
- (int)load { 
	if(!verified) {
		ASIHTTPRequest* fetch = [ASIHTTPRequest requestWithURL:URL];
		[CKUtil setProxy:[[NSUserDefaults standardUserDefaults] URLForKey:@"CKProxySetting"] onRequest:&fetch];
		[fetch startSynchronous];
		int err;
		if((err = [CKUtil validateResponse:fetch]) != CK_ERR_SUCCESS)
			return err;
		image = [[fetch responseData] retain];
		NSString* tmpMD5 = [CKUtil MD5:image];
		if(!MD5) MD5 = [tmpMD5 retain];
		else if(![MD5 isEqualToString:tmpMD5]){
			DLog(@"Hash differs: %@ : %@",MD5,tmpMD5);
			return CK_ERR_CHECKSUM;
		}
		verified = true;
		DLog(@"Verified MD5: %@",MD5);
	}
	return CK_ERR_SUCCESS;
}
- (NSString*)formattedSize {
	return size > 1048576 ? [NSString stringWithFormat:@"%.2f MB",size/1048576.0] : [NSString stringWithFormat:@"%u KB",size/1024];
}
- (NSString*)formattedResolution {
	return [NSString stringWithFormat:@"%0.0fx%0.0f",resolution.width,resolution.height];
}
- (NSString*)formattedTimestamp {
	NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
	[formatter setDateFormat:[[CKRecipe sharedRecipe] lookup:@"Definitions.Dates.Format"]];
	return [formatter stringFromDate:timestamp];
}
- (NSString*)description {
	return [NSString stringWithFormat:@"%cFile : %@-(%@%@, %@%@, %@)",
			NSNewlineCharacter,[URL lastPathComponent],spoiler ? @"Spoiler Image, " : @"",self.formattedSize,self.formattedResolution,
			name ? [NSString stringWithFormat:@", %@",name] : @"",self.formattedTimestamp];
}

- (NSString*)prettyPrint {
	return [NSString stringWithFormat:@"%cFile : \e[4;34m%@\e[0m-(%@%@, %@%@, %@)",
			NSNewlineCharacter,[URL lastPathComponent],spoiler ? @"Spoiler Image, " : @"",self.formattedSize,self.formattedResolution,
			name ? [NSString stringWithFormat:@", %@",name] : @"",self.formattedTimestamp];
}

- (NSXMLNode*)XMLRepresentation {
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

	NSXMLNode* xmlthumb = [NSXMLElement elementWithName:@"img" children:nil
											 attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"src" stringValue:thumbpath]]];

	// Need some way to signal whether we intend to store the image, unless the href attr can be removed from the document later
	NSXMLNode* xmlimage = [NSXMLElement elementWithName:@"a"
											   children:[NSArray arrayWithObject:xmlthumb]
											 attributes:[NSArray arrayWithObjects:
														 [NSXMLNode attributeWithName:@"href" stringValue:imgpath],
														 [NSXMLNode attributeWithName:@"class" stringValue:@"image"],
														 [NSXMLNode attributeWithName:@"data-timestamp" stringValue:self.formattedTimestamp],
														 [NSXMLNode attributeWithName:@"data-width" stringValue:
														  [NSString stringWithFormat:@"%0.0f",self.resolution.width]],
														 [NSXMLNode attributeWithName:@"data-height" stringValue:
														  [NSString stringWithFormat:@"%0.0f",self.resolution.height]],
														 [NSXMLNode attributeWithName:@"data-size" 
																		  stringValue:[NSString stringWithFormat:@"%d",size]],
														 [NSXMLNode attributeWithName:@"data-md5" stringValue:MD5],
														 [NSXMLNode attributeWithName:@"data-name" stringValue:name],
														 [NSXMLNode attributeWithName:@"data-origin" stringValue:[URL absoluteString]],nil]];
	
	NSXMLNode* xmlfile = [NSXMLElement elementWithName:@"a"
											  children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:[imgpath lastPathComponent]]]
											attributes:[NSArray arrayWithObjects:
														[NSXMLNode attributeWithName:@"href" stringValue:imgpath],
														[NSXMLNode attributeWithName:@"class" stringValue:@"image-path"],nil]];

	NSXMLNode* xmlsize = [NSXMLElement elementWithName:@"span"
											  children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:self.formattedSize]]
											attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class" stringValue:@"image-size"]]];

	NSXMLNode* xmlres = [NSXMLElement elementWithName:@"span"
											 children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:self.formattedResolution]]
										   attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class" 
																								stringValue:@"image-resolution"]]];
	
	NSXMLNode* xmlname = [NSXMLElement elementWithName:@"span"
											  children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:name]]
											attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class" stringValue:@"image-name"]]];
	
	NSXMLNode* xmltime = [NSXMLElement elementWithName:@"span"
											  children:[NSArray arrayWithObject:[NSXMLNode textWithStringValue:self.formattedTimestamp]]
											attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class"
																								 stringValue:@"image-timestamp"]]];
	

	NSXMLNode* xmlcomma = [NSXMLNode textWithStringValue:@", "];
	NSXMLNode* xmldescription = [NSXMLElement elementWithName:@"span"
													 children:[NSArray arrayWithObjects:[NSXMLNode textWithStringValue:@"File: "],
																						xmlfile,[NSXMLNode textWithStringValue:@" - ("],
																						xmlsize,xmlcomma,xmlres,xmlcomma,xmlname,xmlcomma,xmltime,
																						[NSXMLNode textWithStringValue:@")"],nil]
											 attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class" 
																								  stringValue:@"image-description"]]];
	return [NSXMLElement elementWithName:@"div"
								children:[NSArray arrayWithObjects:xmldescription,xmlimage,nil]
							  attributes:[NSArray arrayWithObject:[NSXMLNode attributeWithName:@"class" stringValue:@"file"]]];

}

- (NSUInteger)hash { return [image hash]; }

@end
