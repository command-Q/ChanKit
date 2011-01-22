/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2009-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKPost.m - Data from a single post. Core building block of the framework.
 *
 *	Note the difference between the various initializers in this and other classes. 
 *	Since ChanKit was initially conceived for iOS, it is architected to be as network-efficient as possible and to go as far as possible
 *	with the data it fetches. 
 *	
 *	CKPost shares various methods with other classes in the framework, all of which behave similarly. The basics are as follows:
 *
 *		@initByReferencingURL	Fills in as many fields as possible without resolving the URL.
 *		@initWithURL			Fully resolves the URL and populates data. Identical to calling @populate following @initByReferencingURL.
 *		@initWithXML			Construct the object from previously-fetched XML data.
 *
 *		@populate				Resolve data to finish constructing an object that was initialized by referencing a URL.
 *									This method returns 0 on success or an integer error code roughly corresponding to the relevant
 *									HTTP status code specification. This may be replaced with an NSError-based system in the future.
 *		@populate:(NSXMLNode*)	Finalizes construction of the object from an existing XML document or node. Called by @populate itself after
 *									fetching the XML data.
 *
 *	Each aforementioned init method has a corresponding factory method.
 *	Keep in mind that these methods hit the network: 
 *		@initWithURL, @populate
 *	While these do not:
 *		@initByReferencingURL, @initWithXML, @populate:(NSXMLNode*)
 */

@class CKUser;
@class CKImage;
@class CKThread;

// Not so sure about this
typedef struct {
	NSMutableArray* values;	//NSString or CKPost
	NSMutableArray* ranges;	//NSValue (NSRange)
	//The two arrays should always be equal in size, but if one is smaller, store that to avoid bad accesses
	NSUInteger count;	
} ranges_s;

@interface CKPost : NSObject {
	NSURL* URL;
	int ID;
	int thread;
	NSUInteger index;
	NSString* board;
	CKUser* user;
	CKImage* image;
	NSDate* date;
	NSString* subject;
	NSString* comment;
	ranges_s quotes;
	ranges_s inlinequotes;
	ranges_s adminmessages;
	BOOL OP;
	BOOL sticky;
	BOOL closed;
	BOOL banned;
	BOOL deleted;
}
@property(nonatomic,readonly,copy) NSURL* URL;
@property(nonatomic,readonly,assign) int ID;
@property(nonatomic,readonly,assign) int thread;
@property(nonatomic,readonly,assign) NSUInteger index;
@property(nonatomic,readonly,copy) NSString* board;
@property(nonatomic,readonly,copy) CKUser* user;
@property(nonatomic,readonly,copy) CKImage* image;
@property(nonatomic,readonly,copy) NSString* subject;
@property(nonatomic,readonly,copy) NSString* comment;
@property(nonatomic,readonly,copy) NSDate* date;
@property(nonatomic,readonly,copy) NSArray* adminmessages;
@property(nonatomic,readonly,copy) NSArray* quotes;
@property(nonatomic,readonly,copy) NSArray* inlinequotes;
@property(nonatomic,readonly,assign) BOOL OP;
@property(nonatomic,readwrite,assign) BOOL sticky;
@property(nonatomic,readwrite,assign) BOOL closed;
@property(nonatomic,readwrite,assign) BOOL banned;
@property(nonatomic,readwrite,assign) BOOL deleted;
@property(nonatomic,readonly,copy) NSString* IDString;

- (id)initTestPost;
+ (CKPost*)testPost;
- (id)initByReferencingURL:(NSURL*)url;
+ (CKPost*)postReferencingURL:(NSURL*)url;
- (id)initWithURL:(NSURL*)url;
+ (CKPost*)postFromURL:(NSURL*)url;
- (id)initWithXML:(NSXMLNode*)doc threadContext:(CKThread*)context;
+ (CKPost*)postFromXML:(NSXMLNode*)doc threadContext:(CKThread*)context;
- (void)dealloc;
- (int)populate;
- (void)populate:(NSXMLNode*)doc threadContext:(CKThread*)context;

- (void)addAdminMessage:(NSString*)newcomment;
- (NSString*)commentFilteringQuotes;
- (BOOL)commentContains:(NSString*)astring;
- (BOOL)quoted:(CKPost*)post;
- (NSString*)quoteRelativeToPost:(CKPost*)post;
- (NSString*)description;
- (NSString*)prettyPrint;
- (NSXMLNode*)generateXML;

- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
@end
