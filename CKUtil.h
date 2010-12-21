#import <CommonCrypto/CommonDigest.h>
#import "CKRecipe.h"

@interface CKUtil : NSObject 

+ (NSString*)parseBoard:(NSURL*)url;
+ (NSString*)parseBoardFromString:(NSString*)url;

+ (int)parseThreadID:(NSURL*)aurl;
+ (NSURL*)URLByDeletingFragment:(NSURL*)aurl;
+ (NSURL*)changePost:(NSURL*)original toPost:(int)idno;

+ (int)fetchXML:(DDXMLDocument**)doc fromURL:(NSURL*)URL;
+ (NSString*)version;

+ (NSString*)generatePassword;
+ (NSString*)MD5:(NSData*)data;

@end
