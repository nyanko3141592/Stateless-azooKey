#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
xcodebuild -project azooKeyMac.xcodeproj -scheme azooKeyMac -configuration Release -derivedDataPath .build-macos CODE_SIGNING_ALLOWED=NO PRODUCT_BUNDLE_IDENTIFIER=dev.naoki.inputmethod.StatelessAzooKey build
