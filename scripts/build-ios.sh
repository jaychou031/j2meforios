#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tmp .cache dist
export TMPDIR="$PWD/build/tmp/"
python3 scripts/verify-source.py
python3 scripts/verify-audio.py
cmake -S . -B build/ios -G Xcode \
  -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT=iphoneos \
  -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_OSX_DEPLOYMENT_TARGET=15.5
cmake --build build/ios --config Release --target J2MEForIOS -- \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
python3 scripts/verify-app-audio.py build/ios/Release-iphoneos/J2MEForIOS.app
python3 scripts/package-ipa.py build/ios/Release-iphoneos/J2MEForIOS.app dist/J2MEForIOS-unsigned.ipa
