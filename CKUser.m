/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	CKUser.m - Imageboard user.
 */

#import "CKUser.h"

@implementation CKUser

- (id)init {
	if(self = [super init]) {
		privilege = CK_PRIV_NORMAL;
		password = [[CKUtil generatePassword] retain]; 
	}
	return self;
}

- (id)initWithUserInfo:(NSDictionary*)info {
	if(self = [self init]) {
		for(NSString* key in info) {
			if([key isEqualToString:@"Name"])
				name = [[info objectForKey:key] retain];
			else if([key isEqualToString:@"Tripcode"])
				tripcode.trip = [[info objectForKey:key] retain];
			else if([key isEqualToString:@"Secure Tripcode"])
				tripcode.securetrip = [[info objectForKey:key] retain];
			else if([key isEqualToString:@"Email"])
				email = [[info objectForKey:key] retain];
			else if([key isEqualToString:@"Privilege"])
				privilege = [[info objectForKey:key] intValue];
			else if([key isEqualToString:@"Password"])
				password = [[info objectForKey:key] retain];			
		}
		DLog(@"Name: %@",name);
		DLog(@"Tripcode: %@",tripcode.trip);
		DLog(@"Secure Tripcode: %@",tripcode.securetrip);
		DLog(@"Email: %@",email);
		DLog(@"Privilege: %d",privilege);
		DLog(@"Password: %@",password);
	}	
	return self;
}
+ (CKUser*)userWithInfo:(NSDictionary*)info { return [[[self alloc] initWithUserInfo:info] autorelease]; }

- (id)initWithName:(NSString*)namestring {
	if(self = [self init]) {
		NSString* nm,*tp,*st;
		if([(nm =[namestring stringByMatching:[[CKRecipe sharedRecipe] lookup:@"User/Name/TripString"] capture:1L]) length])
			name = [nm retain];
		if([(tp =[namestring stringByMatching:[[CKRecipe sharedRecipe] lookup:@"User/Tripcode/Regex"]  capture:1L]) length])
			tripcode.trip = [tp retain];
		if([(st =[namestring stringByMatching:[[CKRecipe sharedRecipe] lookup:@"User/SecureTripcode/Regex"]  capture:1L]) length])
			tripcode.securetrip = [st retain];
	}
	return self;
}
+ (CKUser*)userNamed:(NSString*)namestring { return [[[self alloc] initWithName:namestring] autorelease]; }

- (id)initWithXML:(DDXMLNode*)doc {
	if(self = [self init]) {
		if(![doc level]) {
			// doc is root node
			NSURL* URL = [NSURL URLWithString:[doc URI]];
			int thread = [CKUtil parseThreadID:URL];
			BOOL OP;
			int ID;
			if((OP = ![URL fragment] || [[[URL fragment] stringByMatching:@"\\d+"] intValue] == thread)) 
				ID = thread;
			else 
				ID = [[URL fragment] intValue];
			NSString* rootpath = OP ?	[[CKRecipe sharedRecipe] lookup:@"Post/OP"] : 
										[NSString stringWithFormat:[[CKRecipe sharedRecipe] lookup:@"Post/Index"],[NSNumber numberWithInt:ID]];
			DDXMLElement* root = [[doc nodesForXPath:rootpath error:NULL] objectAtIndex:0];
			
			if(root && (self = [self initWithXML:root])) return self;
			return nil;
		}
		name = [[[CKRecipe sharedRecipe] lookup:@"User/Name" inDocument:doc] retain];
		DLog(@"Name: %@",name);
		email = [[[CKRecipe sharedRecipe] lookup:@"User/Email" inDocument:doc] retain];
		DLog(@"Email: %@",email);
		tripcode.trip = [[[CKRecipe sharedRecipe] lookup:@"User/Tripcode" inDocument:doc] retain];
		DLog(@"Tripcode: %@",tripcode.trip);
		tripcode.securetrip = [[[CKRecipe sharedRecipe] lookup:@"User/SecureTripcode" inDocument:doc] retain];
		DLog(@"Secure Tripcode: %@",tripcode.securetrip);
		if		([[CKRecipe sharedRecipe] lookup:@"User/Authority/Admin" inDocument:doc]) privilege = CK_PRIV_ADMIN;
		else if	([[CKRecipe sharedRecipe] lookup:@"User/Authority/Mod" inDocument:doc])	  privilege = CK_PRIV_MOD;		
		DLog(@"Privilege: %d",privilege);
	}
	return self;
}
+ (CKUser*)userFromXML:(DDXMLNode*)doc { return [[[self alloc] initWithXML:doc] autorelease]; }

+ (CKUser*)anonymous { return [[[self alloc] initWithUserInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"Anonymous",@"Name",nil]] autorelease]; }

- (void)dealloc{
	[name release];
	[tripcode.trip release];
	[tripcode.securetrip release];
	[email release];
	[password release];
	[posts release];
	[super dealloc];
}

@synthesize name;
@synthesize email;
@synthesize password;
@synthesize privilege;
@synthesize posts;

- (NSDictionary*)dictionary {
	NSMutableDictionary* dict = [NSMutableDictionary dictionary];
	if(name)
		[dict setObject:name forKey:@"Name"];
	if(tripcode.trip)
		[dict setObject:tripcode.trip forKey:@"Tripcode"];
	if(tripcode.securetrip)
		[dict setObject:tripcode.securetrip forKey:@"SecureTripcode"];
	if(email)
		[dict setObject:email forKey:@"Email"];
	[dict setObject:[NSNumber numberWithInt:privilege] forKey:@"Privilege"];
	if(password)
		[dict setObject:password forKey:@"Password"];
	return dict;
}

- (NSString*)tripcode { return tripcode.trip; }
- (NSString*)securetrip { return tripcode.securetrip; }

- (NSArray*)threads { return [posts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"OP"]]; }

- (NSString*)tripstring {
	NSMutableString* trip = [NSMutableString string];
	if(tripcode.trip) [trip appendFormat:@"!%@",tripcode.trip];
	if(tripcode.securetrip) [trip appendFormat:@"!!%@",tripcode.securetrip];
	return trip;
}
- (NSString*)namestring { 
	NSMutableString* nm = [NSMutableString string];
	if(name) [nm appendString:name];
	[nm appendString:self.tripstring];
	[nm appendFormat:@" %@",self.authority];
	return nm;
}

- (NSString*)authority {
	switch(privilege) {
		case CK_PRIV_ADMIN:	return @"## Admin";
		case CK_PRIV_MOD:	return @"## Mod";
		default:			return @"";
	}
}

- (NSData*)generatePostingData {
	NSMutableString* data = [NSMutableString string];

	NSMutableString* namestring = [NSMutableString string];
	if(name) [namestring appendString:name];
	if(tripcode.trip) [namestring appendFormat:@"#%@",tripcode.trip];
	if(tripcode.securetrip) [namestring appendFormat:@"##%@",tripcode.securetrip];

	if([namestring length]) [data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"name\"\r\n\r\n%@",CK_FORM_BOUNDARY,namestring];
	if(email) [data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"email\"\r\n\r\n%@",CK_FORM_BOUNDARY,email];
	if(password) [data appendFormat:@"\r\n--%@\r\nContent-Disposition: form-data; name=\"pwd\"\r\n\r\n%@",CK_FORM_BOUNDARY,password];

	return [data dataUsingEncoding:NSUTF8StringEncoding];

}

- (BOOL)isEqual:(id)other { return [self hash] == [other hash]; }
- (NSUInteger)hash { return 31 * (31 * (31 * (31 + privilege) + [name hash]) + [tripcode.trip hash]) + [tripcode.securetrip hash]; }
- (NSString*)description {
	if(email) return [self.namestring stringByAppendingFormat:@" (mailto:%@)",email];
	return self.namestring;
}

- (DDXMLNode*)XMLRepresentation {
	DDXMLNode* xmlname = [DDXMLElement elementWithName:@"span" 
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:name]] 						
											attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"name"]]];
	
	DDXMLNode* xmltrip = [DDXMLElement elementWithName:@"span" 
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:tripcode.trip]] 						
											attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"tripcode"]]];
	
	DDXMLNode* xmlstrip = [DDXMLElement elementWithName:@"span" 
											   children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:tripcode.securetrip]]						
											 attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"securetripcode"]]];

	DDXMLNode* xmlauth = [DDXMLElement elementWithName:@"span" 
											  children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:self.authority]]						
											attributes:[NSArray arrayWithObjects:
														[DDXMLNode attributeWithName:@"class" stringValue:@"privilege"],
														[DDXMLNode attributeWithName:@"data-privilege" 
																		 stringValue:[NSString stringWithFormat:@"%d",privilege]],nil]];
	DDXMLNode* xmlemail = [DDXMLElement elementWithName:@"a" 
											   children:[NSArray arrayWithObject:[DDXMLNode textWithStringValue:email]]						
											 attributes:[NSArray arrayWithObjects:
														 [DDXMLNode attributeWithName:@"class" stringValue:@"mail"],
														 [DDXMLNode attributeWithName:@"href" stringValue:[NSString stringWithFormat:@"mailto:%@",email]],nil]];
	
	return [DDXMLElement elementWithName:@"div"
								children:[NSArray arrayWithObjects:xmlname,xmltrip,xmlstrip,xmlauth,xmlemail,nil]
							  attributes:[NSArray arrayWithObject:[DDXMLNode attributeWithName:@"class" stringValue:@"user"]]];
}

@end
