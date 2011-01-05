ChanKit - Mac OS X and iOS framework for interacting with imageboards.
Copyright 2009-2011 command-Q.org. All rights reserved. Contact: tab@command-q.org
This framework is distributed under the terms of the Do What The Fuck You Want To Public License, Version 2.  See the License file for details.
Version 0.9 - This is an early development version with minimal functionality.
NOTE: This is a preview release. This means the API is not stable, feature complete, or guaranteed to work. Use at your own risk.

Use the provided Xcode project (Xcode 3.1 or higher) to build. A small sample command-line application is included which can be used for rudimentary browsing (must currently copy the framework to your Frameworks directory manually to use it).

Things missing in this distribution planned for 1.0 release:
	- More comprehensive tripcode management
	- XML writing
	- Support for -- or at least the capability to fail gracefully on -- unorthodox boards like /f/ and /rs/
	- Board recipes beyond Yotsuba
	- Optimized stat/searching methods (threaded)
	- Recipe format freeze
	- iOS support
	- NSError support for document fetching (currently an integer error code system is in place)
	- Various sample applications
	- New icon

In spite of this, the parsing API is considered mostly stable and ready for development use. Most of the relevant information is documented in the headers (it's not a large framework). Though this framework was first started in March of 2009, it survived long periods of stagnation and several total rewrites.