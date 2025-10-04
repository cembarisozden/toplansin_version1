#!/bin/sh
set -e

# Flutter SDK indir
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$(pwd)/flutter/bin"

flutter --version

# Flutter bağımlılıkları (Generated.xcconfig üretir)
flutter pub get

# CocoaPods
sudo gem install cocoapods

cd ios
pod repo update
pod install --repo-update
cd ..
