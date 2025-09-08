#!/bin/bash
set -e

echo "📦 Очистка и сборка проекта..."
flutter clean
flutter pub get
flutter build ios --release

echo "📂 Создание Payload..."
rm -rf Payload Runner.ipa
mkdir Payload
cp -r build/ios/iphoneos/Runner.app Payload/

echo "📦 Упаковка в .ipa..."
zip -r Runner.ipa Payload >/dev/null
rm -rf Payload

echo "✅ Файл Runner.ipa готов!"
echo "🌐 Открываю Diawi для загрузки..."
open https://www.diawi.com
echo "💡 Перетащи файл Runner.ipa на страницу Diawi, дождись генерации ссылки и открой её на iPhone."

