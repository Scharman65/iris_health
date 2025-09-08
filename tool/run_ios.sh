#!/usr/bin/env bash
set -euo pipefail
echo "› Форматирую код..."
flutter format lib >/dev/null 2>&1 || true
echo "› Получаю зависимости..."
flutter pub get
echo "› Запускаю на подключённом iPhone..."
UDID=$(idevice_id -l | head -n1)
[ -z "$UDID" ] && { echo "Нет подключённого iPhone"; exit 1; }
flutter run -d "$UDID" --no-dds --disable-service-auth-codes --host-vmservice-port=0 --device-vmservice-port=0
