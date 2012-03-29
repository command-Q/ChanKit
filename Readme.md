ChanKit - Mac OS X and iOS framework for interacting with imageboards.

Copyright 2009-2012 [command-Q.org](http://www.command-q.org). All rights reserved. Contact: tab@command-q.org

This framework is distributed under the terms of the *Do What The Fuck You Want To Public License, Version 2*.  See the License file for details.

Version 0.8 - This is a development version with incomplete functionality.

####Building
Use the provided Xcode project (Xcode 3.1 or higher) to build. A sample command-line application is included which can be used for browsing and posting (the framework must be in your framework search path).

####Notes
This is a development release. This means the API is not guaranteed to be stable, feature complete, or fully working. Use with discretion.

Major things missing in this distribution which are planned for the 1.0 release include:

* Error handling with NSError (currently an integer error code system is in place)
* XML and NSData archiving
* Board recipes beyond Yotsuba
* Recipe format freeze
* iOS support


Nevertheless, the high-level API is mostly stable and ready for development use.

Though this framework was created in March of 2009, it has survived long periods of stagnation and several total rewrites.