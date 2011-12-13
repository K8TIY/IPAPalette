#!/bin/bash

cp -r ../build/release/IPAPalette.app ./
cp ../build/release/IPAPalettePostinstall ./
codesign -s blugs.com IPAPalette.app/Contents/MacOS/IPAPalette
codesign -s blugs.com IPAPalettePostinstall
