/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2010-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 * ChanParse.m - Simple example/test app.
 */

#import <Cocoa/Cocoa.h>
#import <ChanKit/ChanKit.h>

int randint(int max) { return random()/(RAND_MAX+1.0)*max; }

int main (int argc, const char * argv[]) {
    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	NSUserDefaults* args = [NSUserDefaults standardUserDefaults];
	if(![[args volatileDomainForName:NSArgumentDomain] count]) {
		NSLog( @"ChanParse - ChanKit test interface.\n"
			  "\t©2010 command-Q.org\n"
			  "\tFramework version %@\n"
			  "\n"
			  "Usage: \tChanParse -chan -board -page -thread -post\n"
			  "\tChanParse -url <URL> -watch -dump\n"
			  "\tChanParse -post <URL> -name -trip -strip -email -password -subject -comment -file\n"
			  "\tChanParse -random YES\n"
			  "\tChanParse -filter <path> -against <URL>\n"
			  "\n"
			  "Supported sites: %@\n"
			  "Supported board software: %@\n"
			  "\n"
			  "Modes:\n"
			  "Navigation (all fields optional):\n"
			  "\n"
			  "\t-chan <string>\tOne of the supported imageboards [4chan]\n"
			  "\t-board <string>\tA board name on the imageboard specified with -c [g]\n"
			  "\t-page <int>\tPage number [0]\n"
			  "\t-thread <int>\tThread index on page [0]\n"
			  "\t-post <int>\tPost index in thread, or -1 for most recent [-1]\n"
			  "\n"
			  "URL:\n"
			  "\n"
			  "\t-url <URL>\tA thread to print\n"
			  "\t-dump <path>\tPath to dump images to (optional)\n"
			  "\t-watch YES\tInstead of exiting, watch and print changes to thread until it 404s (optional - global setting)\n"
			  "\t\t(YES must be passed to work with NSUserDefaults, we don't really want getopt for this tiny sample app.)\n"
			  "\t-retry <int>\tIf images fail to load, retry n times [0 - unlimited] (optional)\n"
			  "\n"
			  "Post:\n"
			  "\n"
			  "\t-post <URL>\tBoard or thread URL to post to\n"
			  "\t-name <string>\tName (optional)\n"
			  "\t-trip <string>\tTripcode (optional)\n"
			  "\t-strip <string>\tSecure Tripcode (optional)\n"
			  "\t-email <string>\tEmail (optional)\n"
			  "\t-password <string>\tPosting password (optional)\n"
			  "\t-subject <string>\tPost subject (optional)\n"
			  "\t-comment <string>\tComment to post (optional if uploading a file)\n"
			  "\t-file <path>\tFile path to post (optional if posting a comment) or directory to dump\n"
			  "\t-spoiler YES\tImage(s) should be marked as spoilers\n"
			  "\t-proxies <path>\tA text file containing a list of proxies to alternate between when dumping a folder\n"
			  "\t-progress YES\tAppend the number of images being dumped to comment\n"
			  "\t-resume YES\tIn a thread, only post images named differently from those already present\n"
			  "\t-dubs YES\tTry to get doubles\n"
			  "\n"
			  "Random:\n"
			  "\t-random YES\tGet a randomized post.\n"
			  "\n"
			  "Proxy:\n"
			  "\t-proxy <URL>\tGet/post using a proxy ([http|https|socks]://host:port) - global setting\n"
			  "\t-filter <path> -against <URL>\tTest a list of proxies against a specified URL, printing valid ones\n"
			  "\n"
			  "Since no options were provided, the defaults will be used now.\n"
			  "\n",
			  [CKUtil version],[[[CKRecipe sharedRecipe] supportedSites] componentsJoinedByString:@", "],
			  [[[CKRecipe sharedRecipe] supportedSoftware] componentsJoinedByString:@", "]);
		
		// This would already be handled by the argument defaults, but it's a good demo of the kit's convenience methods
		CKPost* post = [[[[CKChan chanNamed:@"4chan"] boardNamed:@"g"] getPage:0] newestPost];
		NSLog(@"%@\n%@",post.URL,[post prettyPrint]);
		[pool drain];
		return 0;
	}
	
	if([args stringForKey:@"proxy"]) {
		NSURL* proxy = [NSURL URLWithString:[args stringForKey:@"proxy"]];
		if(![proxy host]) // Most likely the scheme was ommitted
			proxy = [NSURL URLWithString:[@"http://" stringByAppendingString:[args stringForKey:@"proxy"]]];
		[args setURL:proxy forKey:@"CKProxySetting"];
		NSLog(@"Using proxy %@",[args URLForKey:@"CKProxySetting"]);
	}
	
	NSURL* url = nil;
	id resource = nil;
	int images = 0;
	NSFileManager* fileman = [[NSFileManager alloc] init];
	NSURL* path = nil;

	if([args stringForKey:@"url"]) {
		url = [NSURL URLWithString:[args stringForKey:@"url"]];
		switch([[CKRecipe sharedRecipe] resourceKindForURL:url]) {
			case CK_RESOURCE_POST:   resource = [CKPost postFromURL:url];     break;
			case CK_RESOURCE_THREAD: resource = [CKThread threadFromURL:url]; break;
			case CK_RESOURCE_BOARD:  resource = [CKPage pageFromURL:url];     break;
			default: resource = nil;
		}
		if(resource) {
			NSLog(@"%@",[resource URL]);
			// NSLog isn't really seamless with this
			[(NSFileHandle*)[NSFileHandle fileHandleWithStandardOutput] writeData:
			 [[[resource prettyPrint] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
			if([resource isKindOfClass:[CKThread class]] && (path = [args URLForKey:@"dump"])) {
				path = [[path URLByAppendingPathComponent:[resource board]] URLByAppendingPathComponent:[resource IDString]];
				NSError* err;
				if([fileman createDirectoryAtPath:[path path] withIntermediateDirectories:YES attributes:nil error:&err]) {
					NSLog(@"Dumping %d images to %@",[resource imagecount],[path path]);
					for(CKImage* image in [resource images])
						if(![fileman fileExistsAtPath:[[path URLByAppendingPathComponent:image.name] path]]) {
							int res, i = [args integerForKey:@"retry"];
							do { res = [image load]; } while(res != CK_ERR_SUCCESS && (!i || --i));
							if(res == CK_ERR_SUCCESS) {
								[fileman createFileAtPath:[[path URLByAppendingPathComponent:image.name] path]
								                 contents:image.data
								               attributes:[NSDictionary dictionaryWithObject:image.timestamp forKey:@"NSFileModificationDate"]];
								images++;
							}
						}
					NSLog(@"Dump complete! Got %d images.",images);
				}
				else NSLog(@"Directory error; path cannot be created at %@\n%@",path,[err localizedDescription]);
			}			
		}
		else NSLog(@"404");
	}
	else if([args stringForKey:@"post"]) {
		url = [NSURL URLWithString:[args stringForKey:@"post"]];
		NSMutableString* rewritecomment = [NSMutableString string];
		switch([[CKRecipe sharedRecipe] resourceKindForURL:url]) {
			case CK_RESOURCE_THREAD: NSLog(@"Posting in thread:\n%@",[[CKPost postFromURL:url] prettyPrint]); break;
			case CK_RESOURCE_BOARD:  NSLog(@"Posting new thread on /%@/",[CKUtil parseBoard:url]);            break;
			case CK_RESOURCE_POST:
				resource = [CKPost postFromURL:url];
				[rewritecomment appendFormat:@">>%d\n",[resource ID]];
				NSLog(@"Responding to post:\n%@",[resource prettyPrint]);
		}

		int runs = 1;
		NSArray* uploads = nil;
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObject:url forKey:@"URL"];
		if([args stringForKey:@"name"])
			[dict setObject:[args stringForKey:@"name"] forKey:@"Name"];
		if([args stringForKey:@"trip"])
			[dict setObject:[args stringForKey:@"trip"] forKey:@"Tripcode"];
		if([args stringForKey:@"strip"])
			[dict setObject:[args stringForKey:@"strip"] forKey:@"Secure Tripcode"];
		if([args stringForKey:@"email"])
			[dict setObject:[args stringForKey:@"email"] forKey:@"Email"];
		if([args stringForKey:@"password"])
			[dict setObject:[args stringForKey:@"password"] forKey:@"Password"];
		else
			[dict setObject:[CKUtil generatePassword] forKey:@"Password"]; // Use a single password for dumps
		if([args stringForKey:@"subject"])
			[dict setObject:[args stringForKey:@"subject"] forKey:@"Subject"];
		if([args stringForKey:@"comment"])
			[rewritecomment appendString:[args stringForKey:@"comment"]];
		if([args URLForKey:@"file"]) {
			BOOL dir;
			[[NSFileManager defaultManager] fileExistsAtPath:[[args URLForKey:@"file"] path] isDirectory:&dir];
			if(!dir) uploads = [NSArray arrayWithObject:[args URLForKey:@"file"]];
			else     uploads = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:[args URLForKey:@"file"]
				                                             includingPropertiesForKeys:[NSArray arrayWithObject:NSURLTypeIdentifierKey]
				                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
				                                                                  error:NULL];
			runs = [uploads count];
		}
		[dict setObject:[NSNumber numberWithBool:[args boolForKey:@"spoiler"]] forKey:@"Spoiler"];
		
		if([rewritecomment length])
			[dict setObject:rewritecomment forKey:@"Comment"];
		 
		NSArray* previousimages = [NSArray array];
		if([args boolForKey:@"resume"])
			previousimages = [[CKThread threadFromURL:url] images];
			
		NSMutableArray* posters = [NSMutableArray arrayWithCapacity:runs];
	 	NSFileHandle* input = [NSFileHandle fileHandleWithStandardInput];
		for(int i = 0; i < runs; i++) {
			if(uploads) {
				if([[previousimages filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"name = %@",[[uploads objectAtIndex:i] lastPathComponent]]] count]) {
					NSLog(@"Ignoring %d of %d (%@)",i+1,runs,[uploads objectAtIndex:i]);
					continue;
				}
					
				NSString* UTI;
				[[uploads objectAtIndex:i] getResourceValue:&UTI forKey:NSURLTypeIdentifierKey error:NULL];
				if(UTTypeConformsTo((CFStringRef)UTI,(CFStringRef)@"public.jpeg") || 
				   UTTypeConformsTo((CFStringRef)UTI,(CFStringRef)@"com.compuserve.gif") ||
				   UTTypeConformsTo((CFStringRef)UTI,(CFStringRef)@"public.png"))
					[dict setObject:[uploads objectAtIndex:i] forKey:@"File"];
				else {
					NSLog(@"Ignoring %d of %d (%@)",i+1,runs,[uploads objectAtIndex:i]);
					continue;
				}
			}

			NSLog(@"Initializing Poster %d of %d",i+1,runs);
			CKPoster* poster;
			do {
				poster = [CKPoster posterWithDictionary:dict];
				
				NSLog(@"Captcha:");	
				const char* temp =[[NSTemporaryDirectory() stringByAppendingPathComponent:@"captcha.XXXXXX.jpg"] fileSystemRepresentation];
				char tempfile[strlen(temp)+1];
				strcpy(tempfile,temp);
				mkstemps(tempfile,4);
				NSString* captcha = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempfile length:strlen(tempfile)];
			
				[poster.captcha.data writeToFile:captcha atomically:NO];
				[[NSWorkspace sharedWorkspace] openFile:captcha];
			
				NSData* data = [input availableData];
				NSString* str = [[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:NSUTF8StringEncoding];
				poster.verification = [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
				[str release];
				[[NSFileManager defaultManager] removeItemAtPath:captcha error:NULL];
			} while(![poster verify:nil]);
			[posters addObject:poster];
		}
		
		NSArray* proxies = [NSArray array];
		if([args URLForKey:@"proxies"])
			proxies = [[[NSString stringWithContentsOfURL:[args URLForKey:@"proxies"] encoding:NSUTF8StringEncoding error:NULL]
			             stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
			                componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		BOOL error = NO;
		NSDate* firstpost = [NSDate date];
		NSDate* lastpost = [NSDate date];
		NSTimeInterval sleep = 0;
		for(int i = 0; !error && i < [posters count]; i++) {
			CKPoster* current = [posters objectAtIndex:i];
			NSString* progress = [NSString stringWithFormat:@"%d of %d",i+1,[posters count]];
			NSLog(@"Posting %@",progress);
			if([args boolForKey:@"progress"]) {
				if(current.comment)	current.comment = [current.comment stringByAppendingFormat:@"\n%@",progress];
				else current.comment = progress;
			}
			if([proxies count] && !(i  % [proxies count])) firstpost = [NSDate date];

			NSURL* proxy;
			if([proxies count]) {
				proxy = [NSURL URLWithString:[proxies objectAtIndex:i % [proxies count]]];
				if(![proxy host]) // Most likely the scheme was ommitted
					proxy = [NSURL URLWithString:[@"http://" stringByAppendingString:[proxies objectAtIndex:i % [proxies count]]]];
				[args setURL:proxy forKey:@"CKProxySetting"];
				NSLog(@"Using proxy %@",[args URLForKey:@"CKProxySetting"]);
			}

			sleep += [lastpost timeIntervalSinceNow];
			if(sleep > 0)
				[NSThread sleepForTimeInterval:sleep];

			int err;
			CKPost* post;
			if([args boolForKey:@"dubs"])
				post = [current post:&err attempt:dubs];
			else
				post = [current post:&err];
			
			lastpost = [NSDate date];
			sleep = 20;
			if(i == [posters count] - 1 || ([proxies count] && ((i + 1) % [proxies count] || [[NSDate date] timeIntervalSinceDate:firstpost] >= 40))) 
				sleep = 0;
			else if(current.file) sleep = 40;

			if(err == CK_ERR_SUCCESS)
				while((err = [post populate]) == CK_ERR_NOTFOUND)
					[NSThread sleepForTimeInterval:2];
			if(err == CK_ERR_SUCCESS) {
				NSLog(@"%@\n%@",post.URL,[post prettyPrint]);
				resource = post;
				if(post.OP) //Reply to ourself
					[posters makeObjectsPerformSelector:@selector(setURL:) withObject:post.URL];
			}
			else { 
				NSLog(@"Error: %@",[CKUtil describeError:err]);
				switch(err) {
					case CK_POSTERR_FLOOD: sleep += sleep ? 20 : 0; break;
					case CK_POSTERR_DUPLICATE:
						[post populate];
						NSLog(@"Duplicate at: %@\n%@",[post.URL absoluteString],[post prettyPrint]);
					case CK_POSTERR_VERIFICATION:
					case CK_ERR_NETWORK: sleep = 0; break;
					case CK_POSTERR_DISALLOWED:
					case CK_POSTERR_NOTFOUND: error = YES; break;
				}
			}	
		}
	}
	else if([args boolForKey:@"random"]) {
		srandom(time(NULL));
		NSArray* supported = [[CKRecipe sharedRecipe] supportedSites];
		CKChan* chan = [CKChan chanNamed:[supported objectAtIndex:randint([supported count])]];
		NSString* name;
		do name = [[chan.boards objectAtIndex:randint([chan.boards count])] name];
		while([name isEqualToString:@"f"]); // This sure is ugly
		CKBoard* board = [chan boardNamed:name];
		CKPage* page = [board getPage:randint(board.numpages)];
		CKThread* thread = [page getThread:randint([page.threads count])];
		CKPost* post = [thread.posts objectAtIndex:randint(thread.postcount)];
		NSLog(@"%@\n%@",post.URL,[post prettyPrint]);
	}
	else if([args URLForKey:@"filter"] && [args stringForKey:@"against"]) {
		// I've gotten a nonrepeateable segfault and bus error here, if anyone has any ideas...
		url = [NSURL URLWithString:[args stringForKey:@"against"]];
		if([[NSFileManager defaultManager] fileExistsAtPath:[[args URLForKey:@"filter"] path]]) {
			NSArray* proxies = [[[NSString stringWithContentsOfURL:[args URLForKey:@"filter"] encoding:NSUTF8StringEncoding error:NULL]
			                      stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]
			                         componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			// Set up recipe
			[[CKRecipe sharedRecipe] detectSite:url];
			[proxies enumerateObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
				NSURL* proxy = [NSURL URLWithString:obj];
				if(![proxy host]) // Most likely the scheme was ommitted
					proxy = [NSURL URLWithString:[@"http://" stringByAppendingString:obj]];
				NSXMLDocument* tempdoc;
				if([CKUtil fetchXML:&tempdoc fromURL:url throughProxy:proxy allowedRedirects:5] == CK_ERR_SUCCESS) {
					// Use standard output so that list can be redirected to a file
					// Note: this sometimes gives false positives on proxies that resolve to some access page
					[(NSFileHandle*)[NSFileHandle fileHandleWithStandardOutput] writeData:
					   [[[proxy absoluteString] stringByAppendingString:@"\n"] dataUsingEncoding:NSUTF8StringEncoding]];
				}
			}];
		}
		else NSLog(@"%@ cannot be read.",[args URLForKey:@"filter"]);
	}
	else {
		if(![args stringForKey:@"chan"])  [args setObject:@"4chan" forKey:@"chan"];
		if(![args stringForKey:@"board"]) [args setObject:@"g" forKey:@"board"];
		
		int index;
		CKChan* chan;
		CKBoard* board;
		CKPage* page;
		CKThread* thread;
		if(!(chan = [CKChan chanNamed:[args stringForKey:@"chan"]]))
			NSLog(@"The site %@ is unsupported!",[args stringForKey:@"chan"]);
		else if(!(board = [chan boardNamed:[args stringForKey:@"board"]]))
			NSLog(@"%@ doesn't appear to have a board named %@.",[args stringForKey:@"chan"],[args stringForKey:@"board"]);
		else if(!(resource = page = [board getPage:[args integerForKey:@"page"]]))
			NSLog(@"There's no page numbered %d.",[args integerForKey:@"page"]);
		else if([args objectForKey:@"thread"] && !(resource = thread = [page getThread:[args integerForKey:@"thread"]]))
			NSLog(@"There doesn't seem to be a thread with index %d.",[args integerForKey:@"thread"]);
		else if([args objectForKey:@"post"] && ((index = [args integerForKey:@"post"]) > thread.postcount || 
		       !(resource = index < 0 ? thread.latest : [thread.posts objectAtIndex:index])))
				NSLog(@"There's no post at index %d.",index);
		else NSLog(@"%@\n%@",[resource URL],[resource prettyPrint]);
	}
	
	if(resource && [args boolForKey:@"watch"] && ([resource isKindOfClass:[CKThread class]] || [resource isKindOfClass:[CKPost class]])) {
		// This mess wonderfully illustrates the need for the CKBrowser delegate
		int lastindex;
		int watchimages = 0;
		int fetchresult; // If we populate in the loop header the autorelease pool won't do any good
		CKThread* thread;
		CKPost* post;
		BOOL postscope;
		if([resource isKindOfClass:[CKPost class]]) {
			postscope = YES;
			thread = [[CKThread alloc] initWithURL:url];
			// In case the thread structure has changed since
			lastindex = [thread.posts indexOfObjectPassingTest:^(id obj, NSUInteger idx, BOOL *stop) {
				return *stop = [obj ID] == [resource ID];
			}];
			post = [[thread.posts objectAtIndex:lastindex] retain];
			lastindex++;
			[(NSFileHandle*)[NSFileHandle fileHandleWithStandardOutput] writeData:[[NSString stringWithFormat:@"\n\e[4m%110s\e[0m\n",""]
			   dataUsingEncoding:NSUTF8StringEncoding]];
		}
		else {
			postscope = NO;
			thread = [resource retain];
			lastindex = thread.postcount;
			post = [thread.OP retain];
		}
		do {
			NSAutoreleasePool* loop = [[NSAutoreleasePool alloc] init];
			NSArray* updates = [thread postsFromIndex:lastindex];
			if([updates count]) {
				if(postscope)
					updates = [updates objectsAtIndexes:[updates indexesOfObjectsPassingTest:^(id p, NSUInteger idx, BOOL *stop) { 
						return [p quoted:post]; 
					}]];
				for(CKPost* p in updates) {
					[(NSFileHandle*)[NSFileHandle fileHandleWithStandardOutput] writeData:
					   [[NSString stringWithFormat:@"\n%@\n\e[4m%110s\e[0m\n",[p prettyPrint],""] dataUsingEncoding:NSUTF8StringEncoding]];
					if(path && p.image && ![fileman fileExistsAtPath:[[path URLByAppendingPathComponent:p.image.name] path]]) {
						int res, i = [args integerForKey:@"retry"];
						do { res = [p.image load]; } while(res != CK_ERR_SUCCESS && (!i || --i));
						if(res == CK_ERR_SUCCESS) {
							[fileman createFileAtPath:[[path URLByAppendingPathComponent:p.image.name] path]
							                 contents:p.image.data
							               attributes:[NSDictionary dictionaryWithObject:p.image.timestamp forKey:@"NSFileModificationDate"]];
							watchimages++;
						}
					}
				}
				lastindex = [thread postcount];						
			}
			else [NSThread sleepForTimeInterval:10];

			fetchresult = [thread populate];
			[loop drain];
		} while(fetchresult != CK_ERR_NOTFOUND && !post.deleted);
		int duration = [[NSDate date] timeIntervalSinceDate:post.date];
		NSLog(@"Thread or post removed, was up for %02d:%02d:%02d",duration/3600,duration/60%60,duration%60);
		if(path) NSLog(@"Got an additional %d images, %d in all.",watchimages,images+watchimages);
		
		[post release];
		[thread release];
	}
	[fileman release];	
	[args removeObjectForKey:@"CKProxySetting"]; // Don't want this to be archived
	[pool drain];
    return 0;
}
