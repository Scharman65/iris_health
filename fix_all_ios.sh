#!/bin/bash
set -e

TARGET_ID="com.rs.irisHealth"
PBX="ios/Runner.xcodeproj/project.pbxproj"
PLIST="ios/Runner/Info.plist"

echo "=== STEP 1: Set unified Bundle ID ==="
gsed -i "s/PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $TARGET_ID;/" $PBX
gsed -i "s/<key>CFBundleIdentifier<\\/key>.*/<key>CFBundleIdentifier<\\/key><string>$TARGET_ID<\\/string>/" $PLIST

echo "=== STEP 2: Clean Pods and ephemeral ==="
cd ios
rm -rf Pods Podfile.lock Flutter/ephemeral
pod install --repo-update
cd ..

echo "=== STEP 3: flutter clean ==="
flutter clean

echo "=== STEP 4: flutter pub get ==="
flutter pub get

echo "=== STEP 5: Verify Flutter.framework ==="
FLUTTER_ROOT=$(fvm flutter --version --machine | jq -r '.flutterRoot')
cp -R "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios/Flutter.xcframework" ios/Flutter/engine/ || true
cp -R "$FLUTTER_ROOT/bin/cache/artifacts/engine/ios-release/Flutter.xcframework" ios/Flutter/engine/ || true

echo "=== STEP 6: Build + Run ==="
flutter run -d 00008110-000958EE01C0401E --no-dds
