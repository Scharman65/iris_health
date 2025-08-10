set -euo pipefail

# 0) Проверка что мы в корне Flutter-проекта
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Запусти из корня проекта (там, где pubspec.yaml)."
  exit 1
fi

# 1) xcconfig: подключаем Pods-Runner.*.xcconfig
pushd ios >/dev/null
mkdir -p Flutter

cat > Flutter/Debug.xcconfig <<'EOF'
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.debug.xcconfig"
#include "Generated.xcconfig"
EOF

cat > Flutter/Release.xcconfig <<'EOF'
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.release.xcconfig"
#include "Generated.xcconfig"
EOF

cat > Flutter/Profile.xcconfig <<'EOF'
#include "Pods/Target Support Files/Pods-Runner/Pods-Runner.profile.xcconfig"
#include "Generated.xcconfig"
EOF

# 2) Обновим platform в Podfile (если закомментировано)
if grep -qE "^# *platform :ios" Podfile 2>/dev/null; then
  /usr/bin/sed -i '' "s|^# *platform :ios.*$|platform :ios, '12.0'|g" Podfile || true
fi

# 3) Пропишем Base Configuration для Target Runner через ruby+xcodeproj
ruby - <<'RUBY'
require 'xcodeproj'
proj = Xcodeproj::Project.open('Runner.xcodeproj')

flutter_group = proj.groups.find { |g| g.name == 'Flutter' } || proj.main_group.new_group('Flutter', 'Flutter')
def ensure_ref(group, path)
  group.files.find { |f| f.path == path } || group.new_file(path)
end

cfg_map = {
  'Debug'   => 'Flutter/Debug.xcconfig',
  'Release' => 'Flutter/Release.xcconfig',
  'Profile' => 'Flutter/Profile.xcconfig'
}

runner = proj.targets.find { |t| t.name == 'Runner' }
raise "Runner target not found" unless runner

cfg_map.each do |name, path|
  ref = ensure_ref(flutter_group, path)
  runner.build_configurations.each do |bc|
    bc.base_configuration_reference = ref if bc.name == name
  end
end

proj.save
puts "✅ Base Configuration set → Flutter/*.xcconfig"
RUBY
popd >/dev/null

# 4) Полная очистка и восстановление зависимостей
echo "🧹 Cleaning DerivedData…"
rm -rf ~/Library/Developer/Xcode/DerivedData || true

echo "🧹 flutter clean…"
flutter clean

echo "📦 flutter pub get…"
flutter pub get

echo "📦 CocoaPods re-install…"
(cd ios && pod deintegrate >/dev/null 2>&1 || true; rm -rf ios/Pods ios/Podfile.lock >/dev/null 2>&1 || true)
(cd ios && pod install)

# 5) Запуск
echo "🚀 flutter run… (разблокируй iPhone и подтверди Local Network, если спросит)"
flutter run
