# CONTEXT HANDOFF — IRIDA / Iris Health

Дата: 2026-01-22T10:03:12+01:00

## Репозиторий Flutter
- Path: /Users/rs/Downloads/iris_health
- Branch: ops/cleanup_repo
- Commit: 6757c1f

## AI Server (FastAPI)
- Path: /Users/rs/Downloads/irida_ai_server
- Base URL (Wi-Fi): http://172.20.10.11:8010
- Health: GET /health
- Analyze: POST /analyze-eye (multipart file)
- Run:
  cd "$HOME/Downloads/irida_ai_server"
  .venv/bin/python -m uvicorn main:app --host 0.0.0.0 --port 8010

## Устройство
- Device name: iPhone Ruslan
- Device id: 00008030-0009449936A0802E

## Версии окружения
- macOS: 26.2 (25C56)
- Xcode: Xcode 26.0.1 Build version 17A400
- Flutter: Flutter 3.38.5 • channel stable • https://github.com/flutter/flutter.git
- Dart: Dart SDK version: 3.10.4 (stable) (Tue Dec 9 00:01:55 2025 -0800) on "macos_arm64"

## Подтверждено (работает)
- AI Settings: Test /health = 200 на iPhone
- /analyze-eye отвечает корректно (quality/zones) и отображается в итогах
- Таймауты для AI вызовов выставлены 90s (camera_screen.dart + irida_ai_bridge.dart)

## Текущая проблема
- Иногда flutter run падает с:
  Error connecting to the service protocol: HttpException: Connection reset by peer
- Цель следующего чата: стабилизировать debug attach / vmService.

## Ключевые файлы (Flutter)
- lib/services/ai_client.dart
- lib/services/diagnosis_service.dart
- lib/screens/ai_settings_screen.dart
- lib/screens/camera_screen.dart
- lib/screens/diagnosis_summary_screen.dart

