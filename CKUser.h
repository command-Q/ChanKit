/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKUser.h - Imageboard user.
 */

@class CKPost;

#define CK_PRIV_NORMAL	0
#define CK_PRIV_MOD		1
#define CK_PRIV_ADMIN	2

// This struct will be deprecated in the near future as tripcodes will be handled by a class of their own.
typedef struct {
	NSString* trip;
	NSString* securetrip;
	BOOL hashed;
} tripcode_s;

@interface CKUser : NSObject {
	NSString* name;
	tripcode_s tripcode;
	NSString* email;
	NSString* password;
	int privilege;
	
	NSMutableArray* posts;
}
@property(nonatomic,readwrite,copy) NSString* name;
@property(nonatomic,readwrite,copy) NSString* email;
@property(nonatomic,readwrite,copy) NSString* password;
@property(nonatomic,readwrite,assign) int privilege;
@property(nonatomic,readonly,assign) NSString* authority;
@property(nonatomic,readwrite,copy) NSArray* posts;
@property(nonatomic,readonly,copy) NSArray* threads;
@property(nonatomic,readonly,copy) NSString* tripcode;
@property(nonatomic,readonly,copy) NSString* securetrip;
@property(nonatomic,readonly,assign) NSString* namestring;
@property(nonatomic,readonly,assign) NSString* tripstring;
@property(nonatomic,readonly,copy) NSDictionary* dictionary;

- (id)initWithUserInfo:(NSDictionary*)info;
+ (CKUser*)userWithInfo:(NSDictionary*)info;
- (id)initWithName:(NSString*)namestring;
+ (CKUser*)userNamed:(NSString*)namestring;
- (id)initWithXML:(NSXMLNode*)doc;
+ (CKUser*)userFromXML:(NSXMLNode*)doc;
+ (CKUser*)anonymous;
- (void)dealloc;

- (BOOL)isEqual:(id)other;
- (NSUInteger)hash;
- (NSString*)description;
- (NSString*)prettyPrint;
- (NSXMLNode*)XMLRepresentation;
@end
