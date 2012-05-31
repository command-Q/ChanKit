/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKImage.h - Cross-compatible wrapper around NSImage with imageboard-specific metadata and convenience routines.
 */

@class NSImage;

@interface CKImage : NSObject {
	NSURL* URL;
	NSData* image;
	NSString* name;
	NSUInteger size;
	NSString* MD5;
	NSSize resolution;
	NSDate* timestamp;
	CKImage* thumbnail;
	BOOL spoiler;
	BOOL verified;
}

@property(nonatomic,readonly) NSURL* URL;
@property(nonatomic,readonly) NSImage* image;
@property(nonatomic,readwrite,copy) NSString* name;
@property(nonatomic,readwrite,assign) NSUInteger size;
@property(nonatomic,readonly) NSString* formattedSize;
@property(nonatomic,readwrite,copy) NSString* MD5;
@property(nonatomic,readwrite,assign) NSSize resolution;
@property(nonatomic,readonly) NSString* formattedResolution;
@property(nonatomic,readwrite,retain) NSDate* timestamp;
@property(nonatomic,readonly) NSString* formattedTimestamp;
@property(nonatomic,readwrite,retain) CKImage* thumbnail;
@property(nonatomic,readonly) NSData* data;
@property(nonatomic,readwrite,assign) BOOL spoiler;
@property(nonatomic,readonly) BOOL loaded;
@property(nonatomic,readonly) BOOL verified;

- (id)initByReferencingURL:(NSURL*)url;
+ (CKImage*)imageReferencingURL:(NSURL*)url;
- (id)initWithContentsOfURL:(NSURL*)url;
+ (CKImage*)imageWithContentsOfURL:(NSURL*)url;
- (id)initWithXML:(NSXMLNode*)doc;
+ (CKImage*)imageFromXML:(NSXMLNode*)doc;
- (void)dealloc;

- (void)setMetadata:(NSDictionary*)meta;
- (int)load;
- (NSString*)description;
- (NSString*)prettyPrint;
- (NSXMLNode*)XMLRepresentation;
- (NSUInteger)hash;

@end
