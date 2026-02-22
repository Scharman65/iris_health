#!/bin/bash
set -e

NEW_ID="com.rs.irisHealthSharm"

echo "=== STEP 1: Updating Bundle ID to $NEW_ID ==="

gsed -i "s/com.rs.irisHealth/$NEW_ID/g" ios/Runner.xcodeproj/project.pbxproj || true
gsed -i "s/com.rs.irisHealth/$NEW_ID/g" ios/Runner/Info.plist || true

gsed -i "s/com.example.irisHealth/$NEW_ID/g" ios/Runner.xcodeproj/project.pbxproj || true
gsed -i "s/com.example.irisHealth/$NEW_ID/g" ios/Runner/Info.plist || true

echo "Bundle ID updated."

echo "=== STEP 2: flutter clean (FULL CLEAN) ==="
flutter clean

echo "=== STEP 3: Removing Pods ==="
rm -rf ios/Pods
rm -f ios/Podfile.lock
rm -rf ios/Flutter/ephemeral
rm -f ios/Flutter/Generated.xcconfig

echo "=== STEP 4: flutter pub get (REGENERATE Generated.xcconfig) ==="
flutter pub get

echo "=== STEP 5: Checking Generated.xcconfig ==="
ls ios/Flutter/ | grep Generated.xcconfig

echo "=== STEP 6: pod install ==="
cd ios
pod install --repo-update
cd ..

echo "=== STEP 7: Opening Xcode ==="
open ios/Runner.xcworkspace

echo "=== DONE! ==="
echo "Now open Xcode → Select TEAM → Product → Run."
