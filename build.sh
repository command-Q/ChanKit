#!/bin/bash
cd "$(dirname $0)"
FORCE=0
INSTALL=0
DESTDIR="release"
while getopts ":dfui" opt; do
	case $opt in
		f)	FORCE=1;;
		u)	CFLAGS="-arch i386 -arch x86_64";;
		d)	DESTDIR="debug"
			DFLAGS="-O0 -g -D_DEBUG";;
		i)	INSTALL=1;;
		\?) echo -e "$0 [-dufi]\n\t-d debug build\n\t-u build universal binary\n\t-f force rebuild\n\t-i install framework and cli to system";;
	esac
done
CFLAGS="-Os $CFLAGS $DFLAGS"
CKUP=0
if [ $FORCE -eq 0 ]; then
	for file in CK*.{h,m}; do
		if [ $file -nt $DESTDIR/ChanKit.framework/Versions/Current/ChanKit ]; then CKUP=1; break; fi
	done
else
	CKUP=1
fi
if [ $CKUP -ne 0 ]; then
	echo Building ChanKit ...
	if [ ! -h $DESTDIR/ChanKit.framework/Versions/Current ]; then
		mkdir -p $DESTDIR/ChanKit.framework/Versions/A/Resources $DESTDIR/ChanKit.framework/Versions/A/Headers
		cd $DESTDIR/ChanKit.framework/Versions
		ln -s A Current
		cd ../../../
	fi

	VERSION=$(grep CK_VERSION_MAJOR Common.h | cut -d' ' -f3).$(grep CK_VERSION_MINOR Common.h | cut -d' ' -f3).$(grep CK_VERSION_MICRO Common.h | cut -d' ' -f3)
	$CC $CFLAGS \
		-framework Cocoa -I.. -include ChanKit_Prefix.pch CKUtil.m CKRecipe.m CKImage.m CKUser.m CKPost.m CKPoster.m CKThread.m CKPage.m CKBoard.m CKChan.m \
		-framework SystemConfiguration -L/usr/lib -licucore -lz RegexKitLite/RegexKitLite.m ASIHTTPRequest/*.m NSData+Base64/NSData+Base64.m \
		-dynamiclib -Wl,-install_name,@rpath/ChanKit.framework/ChanKit,-current_version,$VERSION -o $DESTDIR/ChanKit.framework/Versions/Current/ChanKit

	if [ ! -h $DESTDIR/ChanKit.framework/ChanKit ]; then
		cd $DESTDIR/ChanKit.framework/
		ln -s Versions/Current/* .
		cd ../../
	fi
	
	cp -pR Recipes Info.plist English.lproj ChanKit_thumb.png ChanKit.png $DESTDIR/ChanKit.framework/Resources
	cp -pR CKUtil.h CKRecipe.h CKImage.h CKUser.h CKPost.h CKPoster.h CKThread.h CKPage.h CKBoard.h CKChan.h Common.h ChanKit.h $DESTDIR/ChanKit.framework/Headers
fi
if [ -e ChanKit.framework ]; then rm ChanKit.framework; fi
ln -s $DESTDIR/ChanKit.framework ChanKit.framework
##
if [ $FORCE -ne 0 -o ChanParse.m -nt chanparse ]; then
	echo Building ChanParse ...
	$CC $CFLAGS -F. -framework ChanKit -framework Cocoa -rpath . -o chanparse ChanParse.m
fi

if [ $INSTALL -ne 0 ]; then
	echo Installing ChanKit to ~/Library/Frameworks ...
	rm -rf ~/Library/Frameworks/ChanKit.framework
	cp -pHR ChanKit.framework ~/Library/Frameworks
	echo Installing chanparse to /usr/local/bin ...
	install -s chanparse /usr/local/bin
	install_name_tool -delete_rpath . /usr/local/bin/chanparse
fi
