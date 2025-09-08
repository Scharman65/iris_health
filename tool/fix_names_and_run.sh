#!/usr/bin/env bash
set -euo pipefail

# iOS: Display Name
PLIST="ios/Runner/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName Иридодиагностика" "$PLIST" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string Иридодиагностика" "$PLIST"

# Android: app_name
STR="android/app/src/main/res/values/strings.xml"
if [ -f "$STR" ]; then
  if grep -q 'name="app_name"' "$STR"; then
    sed -E -i '' 's#(<string[[:space:]]+name="app_name">)[^<]*(</string>)#\1Иридодиагностика\2#g' "$STR"
  else
    sed -E -i '' 's#</resources>#  <string name="app_name">Иридодиагностика</string>\n</resources>#' "$STR"
  fi
else
  mkdir -p "$(dirname "$STR")"
  cat > "$STR" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<resources>
  <string name="app_name">Иридодиагностика</string>
</resources>
XML
fi

# Убираем конфликт VM-портов в лаунчере
if [ -f tool/run_ios.sh ] && ! grep -q -- '--host-vmservice-port=0' tool/run_ios.sh; then
  sed -E -i '' 's#flutter run -d "\$UDID" --no-dds --disable-service-auth-codes(.*)#flutter run -d "$UDID" --no-dds --disable-service-auth-codes \\\n  --host-vmservice-port=0 --device-vmservice-port=0 \1#' tool/run_ios.sh
fi

# Запуск
./tool/run_ios.sh
