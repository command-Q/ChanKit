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
@property(nonatomic,readonly,copy) NSURL* URL;
@property(nonatomic,readonly,assign) NSImage* image;
@property(nonatomic,readwrite,copy) NSString* name;
@property(nonatomic,readwrite,assign) NSUInteger size;
@property(nonatomic,readonly,copy) NSString* formattedSize;
@property(nonatomic,readwrite,copy) NSString* MD5;
@property(nonatomic,readwrite,assign) NSSize resolution;
@property(nonatomic,readonly,assign) NSString* formattedResolution;
@property(nonatomic,readwrite,copy) NSDate* timestamp;
@property(nonatomic,readonly,assign) NSString* formattedTimestamp;
@property(nonatomic,readwrite,assign) CKImage* thumbnail;
@property(nonatomic,readonly,assign) BOOL isLoaded;
@property(nonatomic,readonly,copy) NSData* data;
@property(nonatomic,readwrite,assign) BOOL spoiler;
@property(nonatomic,readonly,assign) BOOL verified;

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
