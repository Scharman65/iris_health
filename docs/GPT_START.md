# IRIDA — GPT_START

## Режимы работы
- **ARCHITECT MODE**: архитектура, решения, риски, ADR, план работ, интерфейсы и контракты.
- **IMPLEMENT MODE**: изменение кода, строго пошагово, одна операция за шаг, без риска остановки работающего.
- **OPS MODE**: релизы, сборки, инфраструктура, секреты, бэкапы, мониторинг.

## Непреложные правила
1. Не ломать работающую систему.
2. Любая рискованная правка — сначала бэкап/копия/план отката.
3. Один шаг = одна операция.
4. Перед изменениями фиксируем контракт данных и API.
5. Любые изменения, влияющие на пользовательские данные — через миграции/версионирование.
6. В UI и документации: позиционирование **Wellness** (без “диагноз/лечение”).

## Стратегия продукта (зафиксировано)
- Positioning: **Wellness**
- Architecture: **Clinical-assistant grade**
- Data: **Hybrid (offline-first + optional cloud later)**
- Product: **Commercial**
- Priorities now: **A (stability) + E (pre-launch readiness)**

## Базовые определения
- **Exam**: одно обследование (левый+правый глаз) с метаданными.
- **AI Contract**: `POST /analyze-eye` (multipart) → JSON (zones + quality + meta).
- **Release target**: TestFlight (iOS) + затем Android closed testing.
