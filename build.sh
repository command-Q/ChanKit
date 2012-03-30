#!/bin/bash
cd "$(dirname $0)"
FORCE=0
DESTDIR="release"
CFLAGS="-Os $CFLAGS"
while getopts ":df" opt; do
	case $opt in
		f)	FORCE=1;;
		d)	DESTDIR="debug"
			CFLAGS="$CFLAGS -O0 -g -D_DEBUG";;
		\?) echo -e "$0 [-df]\n\t-d debug build\n\t-f force rebuild";;
	esac
done
CKUP=0
if [ $FORCE -eq 0 ]; then
	for file in CK*.{h,m}; do
		if [ $file -nt $DESTDIR/ChanKit.framework/Versions/Current/ChanKit ]; then CKUP=1; break; fi
	done
else
	CKUP=1
fi
if [ $CKUP -ne 0 ]; then
	echo Building ChanKit...
	if [ ! -h $DESTDIR/ChanKit.framework/Versions/Current ]; then
		mkdir -p $DESTDIR/ChanKit.framework/Versions/A/Resources $DESTDIR/ChanKit.framework/Versions/A/Headers
		cd $DESTDIR/ChanKit.framework/Versions
		ln -s A Current
		cd ../../../
	fi
	
	VERSION=$(grep CK_VERSION_MAJOR Common.h | cut -f 3).$(grep CK_VERSION_MINOR Common.h | cut -f 3).$(grep CK_VERSION_MICRO Common.h | cut -f 3)
	$CC $CFLAGS \
		-framework Cocoa -I.. -include ChanKit_Prefix.pch CKUtil.m CKRecipe.m CKImage.m CKUser.m CKPost.m CKPoster.m CKThread.m CKPage.m CKBoard.m CKChan.m \
		-framework SystemConfiguration -licucore -lz RegexKitLite/RegexKitLite.m ASIHTTPRequest/*.m NSData+Base64/NSData+Base64.m \
		-dynamiclib -Wl,-install_name,$PWD/ChanKit.framework/ChanKit,-current_version,$VERSION -o $DESTDIR/ChanKit.framework/Versions/Current/ChanKit

	if [ ! -h $DESTDIR/ChanKit.framework/ChanKit ]; then
		cd $DESTDIR/ChanKit.framework/
		ln -s Versions/Current/* .
		cd ../../
	fi
	
	sed "s/<string>[0-9]*\.[0-9]*\.[0-9]*<\/string>/<string>$VERSION<\/string>/g" Info.plist > $DESTDIR/ChanKit.framework/Resources/Info.plist
	cp -pR Recipes English.lproj ChanKit_thumb.png ChanKit.png $DESTDIR/ChanKit.framework/Resources
	cp -pR CKUtil.h CKRecipe.h CKImage.h CKUser.h CKPost.h CKPoster.h CKThread.h CKPage.h CKBoard.h CKChan.h Common.h ChanKit.h $DESTDIR/ChanKit.framework/Headers
fi
if [ -e ChanKit.framework ]; then rm ChanKit.framework; fi
ln -s $DESTDIR/ChanKit.framework ChanKit.framework
##
if [ $FORCE -eq 1 -o ChanParse.m -nt /usr/local/bin/chanparse ]; then
	echo Building ChanParse...
	$CC $CFLAGS -F. -framework ChanKit -framework Cocoa -o chanparse ChanParse.m
fi