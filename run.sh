#!/bin/zsh

set -e

echo "🔎 Проверяю USB-подключение iPhone..."

USB_OK=$(system_profiler SPUSBDataType | grep -c "iPhone")

if [ "$USB_OK" -eq 0 ]; then
  echo "❌ iPhone НЕ найден по USB!"
  echo "➡ Проверь кабель и отключи Wireless Debugging"
  exit 1
fi

echo "✅ iPhone найден по USB"

echo "🧹 Чищу старые процессы..."
pkill -f uvicorn 2>/dev/null || true
pkill -f iproxy 2>/dev/null || true
pkill -f flutter_tools 2>/dev/null || true

echo "🚀 Запускаю AI-сервер..."
source .venv/bin/activate
uvicorn iris_ai_server:app --host 0.0.0.0 --port 8010 --reload &
sleep 2

echo "🔌 Запускаю iproxy..."
iproxy 8010 8010 &
sleep 2

echo "🎯 Готово! Теперь запусти Flutter вручную:"
echo ""
echo "fvm flutter run -d 00008110-000958EE01C0401E --dart-define=AI_ENDPOINT=http://127.0.0.1:8010/analyze"
echo ""
echo "👇 Просто вставь эту команду в другой терминал."

