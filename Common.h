/*
 * ChanKit - Imageboard parsing and interaction.
 * Copyright 2009-2012 command-Q.org. All rights reserved.
 * This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.
 *
 * Common.h - Global includes/defines.
 */

#ifndef NSNewlineCharacter
	#define	NSNewlineCharacter   0x000a
#endif

#define CK_VERSION_MAJOR 0
#define CK_VERSION_MINOR 8
#define CK_VERSION_MICRO 6
#define CK_VERSION_TAG   @""
#define CK_VERSION_OS    @"OS X"

#ifdef _DEBUG
	// HTML parsing is extremely messy, so this function is used to dump a ton of data
	#define DLog(...) NSLog(__VA_ARGS__)
#else 
	// Silence our fountain of logs
	#define DLog(...) 
#endif

// Document fetching error codes
#define CK_ERR_UNDEFINED           -1
#define CK_ERR_SUCCESS              0
#define CK_ERR_NETWORK              6
#define CK_ERR_CHECKSUM             7
#define CK_ERR_NOTFOUND           404
#define CK_ERR_PARSER             406
#define CK_ERR_UNSUPPORTED        415
#define CK_ERR_BANNED             403
#define CK_ERR_REDIRECT           302
// Common post rejection reasons, shared code range with above
#define CK_POSTERR_FLOOD            1
#define CK_POSTERR_VERIFICATION     2
#define CK_POSTERR_DUPLICATE        3
#define CK_POSTERR_NOTFOUND         4
#define CK_POSTERR_DISALLOWED       5
#define CK_POSTERR_REJECTED         8
#define CK_POSTERR_FILETYPE         9
#define CK_POSTERR_FAILEDUPLOAD    10

// Imageboard software detection codes (CKRecipe @detectBoardSoftware)
#define CK_DETECTION_COULDNOTPROCEED   -1
#define CK_DETECTION_FAILED             0
#define CK_DETECTION_URL                1
#define CK_DETECTION_TITLE              2
#define CK_DETECTION_FUZZY              3

// Recipe status
#define CK_RECIPE_PRELIMINARY   -1
#define CK_RECIPE_NOMATCH        0
#define CK_RECIPE_URLMATCH       1
#define CK_RECIPE_XMLMATCH       2
#define CK_RECIPE_MANUAL         3

// Resource type identifiers
#define CK_RESOURCE_UNDEFINED   0
#define CK_RESOURCE_IMAGE       1
#define CK_RESOURCE_POST        2
#define CK_RESOURCE_THREAD      3
#define CK_RESOURCE_BOARD       4

#define CK_PROXY_TIMEOUT   60