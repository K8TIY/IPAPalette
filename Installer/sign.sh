#!/bin/bash

cp -r ../build/release/IPA\ Manager.app ./
codesign -s blugs.com IPA\ Manager.app
codesign -s blugs.com IPA\ Manager.app/Contents/SharedSupport/IPAPalette.app
