#! /bin/bash
# Requires the build-dmg script from here:
# https://github.com/andreyvit/yoursway-create-dmg.git

mkdir tmp
rm -f IPAPalette.dmg
cp -r ../build/Release/IPA\ Manager.app tmp
~/Desktop/yoursway-create-dmg/create-dmg --volname "IPA Palette" --background VowLight.png --window-size 500 360 --volicon DMG.icns --icon "IPA\ Manager.app" 60 240 --app-drop-link 380 240 --icon-size 64 IPAPalette.dmg tmp
rm -rf tmp
# Put a copy of your .app (with the same name as the version it’s replacing) in a .zip, .tar.gz, or .tar.bz2.
# If you distribute your .app in a .dmg, do not zip up the .dmg.
ruby ../Sparkle/sign_update.rb IPAPalette.dmg /Volumes/Books/DevKeys/IPAPalette_priv.pem
