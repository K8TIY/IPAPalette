#! /bin/bash
# Requires the build-dmg script from here:
# https://github.com/andreyvit/yoursway-create-dmg.git
mkdir tmp
rm IPAPalette.dmg
cp IPAPalette.pkg tmp
~/Desktop/yoursway-create-dmg/create-dmg --volname IPA\ Palette --background VowLight.png --window-size 500 360 --volicon DMG.icns --icon IPAPalette.pkg 60 240 --icon-size 64 IPAPalette.dmg tmp
rm -rf tmp
