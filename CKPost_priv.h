@interface CKPost()
@property(nonatomic,readwrite) BOOL sticky;
@property(nonatomic,readwrite) BOOL closed;
@property(nonatomic,readwrite) BOOL deleted;
@property(nonatomic,readwrite) NSUInteger index;
@end