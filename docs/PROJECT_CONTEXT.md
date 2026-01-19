# IRIDA — PROJECT_CONTEXT

## 1) Цель
IRIDA — коммерческое wellness-приложение для съёмки радужки (левый/правый глаз), локального хранения обследований и получения AI-анализа с сервера. Архитектура проектируется как clinical-assistant grade: воспроизводимость, контроль версий, трассировка, строгая модель данных.

## 2) Стратегия (подтверждено)
- Wellness positioning
- Clinical-assistant grade architecture
- Hybrid storage (offline-first + optional cloud later)
- Commercial product
- Приоритеты: A (устойчивость) + E (предзапуск)

## 3) Текущее состояние (факты)
- Flutter: 3.38.5 stable, Dart: 3.10.4
- iOS устройства: iPhone 13 / iPhone Ruslan
- AI сервер: FastAPI (uvicorn) + Cloudflare quick tunnel (trycloudflare)
- Эндпоинты:
  - GET/HEAD `/health` → `{"status":"ok"}`
  - POST `/analyze-eye` (multipart: file + form fields) → JSON (`status`, `api_version`, `exam_id`, `eye`, `age`, `gender`, `quality`, `zones`, `took_ms`)
- В приложении есть AiSettingsScreen (редактирование base URL) и AiClient (multipart запрос /analyze-eye)

## 4) Ограничения/неизменяемые правила
- Никаких медицинских утверждений в UI/маркетинге.
- Стабильность важнее скорости.
- Данные пользователя не теряем: бэкапы и миграции.
- Обновление зависимостей — только по плану и пакетами, без “вдруг обновил всё”.

## 5) Ближайшая цель
Стабильный E2E поток:
PatientForm → Camera (left/right) → local save → AI analyze → Results → History → PDF export (позже).

## 6) Риски
- trycloudflare не гарантирует uptime → нужен “стабильный dev tunnel” и/или named tunnel позже
- сеть через модем/хотспот → плавающие адреса/доступность
- iOS фоновые ограничения → нужен режим “сервер на ноутбуке + туннель” с устойчивым запуском
