/*
 *  ChanKit - Imageboard parsing and interaction.
 *  Copyright 2010-2011 command-Q.org. All rights reserved.
 *	This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2. 
 * 
 *	ChanParse.m - Simple example/test app.
 */

#import <ChanKit/ChanKit.h>

int randint(int max) { return random()/(double)RAND_MAX * (double)max; }

int main (int argc, const char * argv[]) {
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

	NSString* url;
	CKChan* chan;
	CKBoard* board;
	CKPage* page;
	CKThread* thread;
	CKPost* post;
	
	NSArray* supportedimagetypes = [NSArray arrayWithObjects:@"png",@"gif",@"jpeg",@"jpg",nil];

	NSUserDefaults* args = [NSUserDefaults standardUserDefaults];
	if(![[args volatileDomainForName:NSArgumentDomain] count]) {
		NSLog( @"ChanParse - ChanKit test interface.\n"
			  "\t©2010 command-Q.org\n"
			  "\tFramework version %@\n"
			  "\n"
			  "Usage: \tChanParse -chan -board -page -thread -post\n"
			  "\t\tChanParse -url <URL> -dump\n"
			  "\t\tChanParse -post <URL> -name -trip -strip -email -password -subject -comment -file\n"
			  "\t\tChanParse -random YES\n"
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
			  "\t-url <string>\tA thread to print\n"
			  "\t-dump <string>\tPath to dump images to (optional)\n"
			  "\n"
			  "Post:\n"
			  "\n"
			  "\t-post <string>\tBoard or thread URL to post to\n"
			  "\t-name <string>\tName (optional)\n"
			  "\t-trip <string>\tTripcode (optional)\n"
			  "\t-strip <string>\tSecure Tripcode (optional)\n"
			  "\t-email <string>\tEmail (optional)\n"
			  "\t-password <string>\tPosting password (optional)\n"
			  "\t-subject <string>\tPost subject (optional)\n"
			  "\t-comment <string>\tComment to post (optional if uploading a file)\n"
			  "\t-file <string>\tFile path to post (optional if posting a comment) or directory to dump\n"
			  "\t-dubs YES\tTry to get doubles\n"
			  "\n"
			  "Random:\n"
			  "\t-random YES\tGet a randomized post.\n"
			  "\t\t(YES must be passed to work with NSUserDefaults, we don't really want getopt for this tiny sample app.)\n"
			  "\n"
			  "Since no options were provided, the defaults will be used now.\n"
			  "\n",
			  [CKUtil version],[[[CKRecipe sharedRecipe] supportedSites] componentsJoinedByString:@", "],
			  [[[CKRecipe sharedRecipe] supportedSoftware] componentsJoinedByString:@", "]);
		
		// This would already be handled by the argument defaults, but it's a good demo of the kit's convenience methods
		post = [[[[[[CKChan chanNamed:@"4chan"] boardNamed:@"g"] getPage:0] threads] objectAtIndex:0] latest];
		NSLog(@"%@\n%@",post.URL,post);
	}
	else if((url = [args stringForKey:@"url"])) {
		thread = [CKThread threadFromURL:[NSURL URLWithString:url]];
		if(!thread)	NSLog(@"404");
		NSLog(@"\n%@",thread);
		NSString* path = [args stringForKey:@"dump"];
		NSFileManager* fileman = [NSFileManager defaultManager];
		if(path && [fileman fileExistsAtPath:path]) {
			path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@"/%@/%d",thread.board,thread.ID]];
			if(![fileman fileExistsAtPath:path])
				[fileman createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:NULL];
			if([fileman fileExistsAtPath:path]) {
				NSLog(@"Dumping %d images to %@",thread.imagecount,path);
				int i = 0;
				for(CKPost* post in [thread imagePosts])
					if(![fileman fileExistsAtPath:[path stringByAppendingPathComponent:post.image.name]]) {
						[fileman createFileAtPath:[path stringByAppendingPathComponent:post.image.name]
										 contents:post.image.data
									   attributes:[NSDictionary dictionaryWithObject:post.image.timestamp
																			  forKey:@"NSFileModificationDate"]];
						i++;
					}
				
				NSLog(@"Dump complete! Got %d images.",i);
			}
			else NSLog(@"Directory error");
		}
		[pool drain];
		return 0;
	}
	else if((url = [args stringForKey:@"post"])) {
		int runs = 1;
		NSArray* uploads = nil;
		NSMutableDictionary* dict = [NSMutableDictionary dictionaryWithObject:[NSURL URLWithString:url] forKey:@"URL"];
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
		if([args stringForKey:@"subject"])
			[dict setObject:[args stringForKey:@"subject"] forKey:@"Subject"];
		if([args stringForKey:@"comment"])
			[dict setObject:[args stringForKey:@"comment"] forKey:@"Comment"];
		if([args stringForKey:@"file"]) {
			BOOL dir;
			[[NSFileManager defaultManager] fileExistsAtPath:[args stringForKey:@"file"] isDirectory:&dir];
			if(!dir)
				uploads = [NSArray arrayWithObject:[args stringForKey:@"file"]];
			else
				uploads = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[args stringForKey:@"file"] error:NULL];
			runs = [uploads count];
		}
		
		NSMutableArray* posters = [NSMutableArray arrayWithCapacity:runs];
		for(int i = 0; i < runs; i++) {
			if(uploads) {
				if([supportedimagetypes containsObject:[[[uploads objectAtIndex:i] pathExtension] lowercaseString]]) {
					if([uploads count] > 1)
						[dict setObject:[[args stringForKey:@"file"] stringByAppendingPathComponent:[uploads objectAtIndex:i]] forKey:@"File"];
					else
						[dict setObject:[uploads objectAtIndex:i] forKey:@"File"];
				}
				else {
					NSLog(@"Ignoring %d of %d (%@)",i+1,runs,[uploads objectAtIndex:i]);
					continue;
				}
			}
			
			NSLog(@"Initializing Poster %d of %d",i+1,runs);
			CKPoster* poster = [CKPoster posterWithDictionary:dict];
			
			NSLog(@"Captcha:");
			
			const char* temp =[[NSTemporaryDirectory() stringByAppendingPathComponent:@"captcha.XXXXXX.tif"] fileSystemRepresentation];
			char* tempfile = malloc(strlen(temp)+1);
			strcpy(tempfile,temp);
			mkstemps(tempfile,4);
			NSString* captcha = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:tempfile length:strlen(tempfile)];
			free(tempfile);
			
			[poster.captcha.data writeToFile:captcha atomically:NO];
			[[NSWorkspace sharedWorkspace] openFile:captcha];
			
			// This breaks in a loop as availableData is always set after the first instance
			/*
			NSFileHandle* input = [NSFileHandle fileHandleWithStandardInput];
			NSData* data;
			
			while(data == nil) data = [input availableData];

			poster.verification = [[NSString stringWithUTF8String:[data bytes]]
								   stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			*/
			char text[100];
			poster.verification = [[NSString stringWithUTF8String:fgets(text,100,stdin)]
								   stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
			[posters addObject:poster];
		}
		int i = 0;
		for(CKPoster* poster in posters) {
			int err;
			if([args boolForKey:@"dubs"])
				post = [poster post:&err attempt:dubs];
			else
				post = [poster post:&err];
			switch(err) {
				case CK_POSTERR_FLOOD:			NSLog(@"Error: Flood");		break;
				case CK_POSTERR_DUPLICATE:		NSLog(@"Error: Duplicate");	break;
				case CK_POSTERR_VERIFICATION:	NSLog(@"Error: Captcha");	break;
				case CK_POSTERR_UNDEFINED:		NSLog(@"Error: Unknown");	break;
				default:NSLog(@"%@\n%@",post.URL,post);
			}
			if(++i < [posters count]) sleep(post.image ? 120 : 60); // These values need to be figured out
		}
	}
	else if([args boolForKey:@"random"]) {
		srandom(time(NULL));
		NSArray* supported = [[CKRecipe sharedRecipe] supportedSites];
		chan = [CKChan chanNamed:[supported objectAtIndex:randint([supported count])]];
		NSString* name;
		do name = [[chan.boards objectAtIndex:randint([chan.boards count])] name];
		while([name isEqualToString:@"f"]); // This sure is ugly
		board = [chan boardNamed:name];
		page = [board getPage:randint(board.numpages)];
		thread = [page getThread:randint([page.threads count])];
		post = [thread.posts objectAtIndex:randint(thread.postcount)];
		NSLog(@"%@\n%@",post.URL,post);
	}
	else {
		if(![args stringForKey:@"chan"])  [args setObject:@"4chan" forKey:@"chan"];
		if(![args stringForKey:@"board"]) [args setObject:@"g" forKey:@"board"];
		if(![args stringForKey:@"post"])  [args setInteger:-1 forKey:@"post"];
		
		if(!(chan = [CKChan chanNamed:[args stringForKey:@"chan"]])) {
			NSLog(@"The site %@ is unsupported!",[args stringForKey:@"chan"]);
			[pool drain];
			return 0;
		}
		if(!(board = [chan boardNamed:[args stringForKey:@"board"]])) {
			NSLog(@"%@ doesn't appear to have a board named %@.",[args stringForKey:@"chan"],[args stringForKey:@"board"]);
			[pool drain];
			return 0;
		}
		if(!(page = [board getPage:[args integerForKey:@"page"]])) {
			NSLog(@"There's no page numbered %d.",[args integerForKey:@"page"]);
			[pool drain];
			return 0;
		}
		if(!(thread = [page getThread:[args integerForKey:@"thread"]])) {
			NSLog(@"There doesn't seem to be a thread with index %d.",[args integerForKey:@"thread"]);
			[pool drain];
			return 0;
		}
		int index;
		if((index = [args integerForKey:@"post"]) < 0)
			post = thread.latest;
		else if(index > thread.postcount) {
			NSLog(@"There's no post at index %d.",index);
			[pool drain];
			return 0;		
		}
		else post = [thread.posts objectAtIndex:index];		
		NSLog(@"%@\n%@",post.URL,post);
	}	
	
	[pool drain];
    return 0;
}
