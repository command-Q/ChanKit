/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * CKPost_priv.h - Internal extension granting write access to some post properties.
*/

@interface CKPost()
@property(nonatomic,readwrite) BOOL sticky;
@property(nonatomic,readwrite) BOOL closed;
@property(nonatomic,readwrite) BOOL deleted;
@property(nonatomic,readwrite) NSUInteger index;
@end