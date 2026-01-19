set -euo pipefail

TS="$(date +%Y%m%d_%H%M%S)"
OUT="diag_ios_$TS.txt"

exec > "$OUT" 2>&1

pwd
date

echo "== flutter doctor =="
flutter doctor -v || true

echo "== flutter pub deps / outdated =="
flutter pub deps --style=compact || true
flutter pub outdated || true

echo "== flutter analyze =="
flutter analyze || true

echo "== ios files check =="
ls -la ios/Runner || true
ls -la ios/Runner | egrep "AppDelegate|SceneDelegate|Main\.storyboard|Info\.plist" || true

echo "== Info.plist SceneDelegate =="
/usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneDelegateClassName" ios/Runner/Info.plist || true
/usr/libexec/PlistBuddy -c "Print :UIApplicationSceneManifest:UISceneConfigurations:UIWindowSceneSessionRoleApplication:0:UISceneStoryboardFile" ios/Runner/Info.plist || true

echo "== Pods =="
cd ios
pod --version || true
pod install || true
cd ..

echo "== Xcode build settings (Debug, iphoneos) =="
cd ios
xcodebuild -version || true
xcodebuild -showBuildSettings -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' | egrep -n "PRODUCT_BUNDLE_IDENTIFIER|PRODUCT_MODULE_NAME|INFOPLIST_FILE|OTHER_LDFLAGS|OTHER_SWIFT_FLAGS|SWIFT_VERSION|SWIFT_OPTIMIZATION_LEVEL|CLANG_DEBUG_INFORMATION_LEVEL|DEBUG_INFORMATION_FORMAT|STRIP_STYLE|STRIP_SWIFT_SYMBOLS|COPY_PHASE_STRIP|GCC_OPTIMIZATION_LEVEL|ENABLE_BITCODE" || true

echo "== xcodebuild build (no codesign) =="
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug -sdk iphoneos -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build || true
cd ..

echo "== Find symbolicatecrash =="
mdfind "symbolicatecrash" | head -n 20 || true

echo "== Recent build artifacts =="
find build/ios -maxdepth 4 -name "Runner.app" -o -name "*.dSYM" 2>/dev/null || true

echo "== Done =="
echo "Saved to $OUT"
