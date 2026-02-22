# CONTEXT HANDOFF — IRIDA

## Current State
- Flutter app builds clean (flutter analyze: 0 issues)
- iPhone 13 release build works
- Camera pipeline stable (macro + sharpness + overlay)
- AI server (FastAPI v0.6.1) reachable via LAN
- /analyze endpoint working (multipart: file_left, file_right)
- PDF generation working
- HiveBootstrap introduced
- HistoryScreen migrated to HiveBootstrap
- ExamStore migrated to HiveBootstrap
- Repo cleaned from generated PDFs/tmp

## Technical Debt
- AiClient.analyzeEye() still targets /analyze-eye (server does not have it)
- Multiple AI service layers: DiagnosisService, irida_api_client, irida_ai_bridge
- Need AI client consolidation

## Next Goal
Unify AI layer to single /analyze endpoint and remove legacy analyzeEye logic.


## 2026-02-22 — AI Layer Consolidation

### Canonical AI Endpoint
POST /analyze
Multipart fields:
  - file_left
  - file_right
  - exam_id
  - age
  - gender
  - locale
  - task=Iridodiagnosis

### Architecture Changes
- AiClient is the single HTTP gateway
- DiagnosisService delegates to AiClient
- Removed:
  - irida_api_client.dart
  - irida_ai_bridge.dart
- Legacy /analyze-eye no longer used in canonical flow
- analysis_options excludes:
  - ops_snapshots/**
  - backups/**

### Status
AI layer: STABLE
Single gateway enforced.
