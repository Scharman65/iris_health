#!/bin/bash
set -e

echo "=== Fixing baseConfigurationReference in project.pbxproj ==="

PBX=ios/Runner.xcodeproj/project.pbxproj

# Remove bad entries
gsed -i '/baseConfigurationReference/d' $PBX

# Add correct entries for Debug/Release/Profile
gsed -i "/Debug = {/a\ \ \ \ \ \ \ \ baseConfigurationReference = \"Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig\";" $PBX
gsed -i "/Release = {/a\ \ \ \ \ \ \ \ baseConfigurationReference = \"Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig\";" $PBX
gsed -i "/Profile = {/a\ \ \ \ \ \ \ \ baseConfigurationReference = \"Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig\";" $PBX

echo "=== Cleaning CocoaPods ==="
cd ios
rm -rf Pods Podfile.lock Flutter/ephemeral
pod install --repo-update
cd ..

echo "=== flutter clean ==="
flutter clean

echo "=== flutter pub get ==="
flutter pub get

echo "=== Running on device ==="
flutter run -d 00008110-000958EE01C0401E --no-dds
