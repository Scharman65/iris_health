# IRIDA — Architecture (high level)

## Mobile (Flutter)
- UI flow: PatientForm → CaptureLeft → CaptureRight → Summary/Results → History
- Offline-first storage (initially local)
- AI client: multipart to /analyze-eye with strict timeout + error mapping
- Settings: AI base URL, health test

## AI Server (dev)
- FastAPI + uvicorn
- /health GET+HEAD
- /analyze-eye multipart parse + response contract
- Tunnel: Cloudflare (quick tunnel now; named tunnel later)

## Data model
- Exam: id, createdAt, age, gender
- Assets: leftImagePath, rightImagePath
- AI result per eye: quality, zones, tookMs, apiVersion
- Derived: overall status, warnings
