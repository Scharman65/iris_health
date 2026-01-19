# IRIDA — Operations (dev)

## Goals
- One-command start for:
  - uvicorn
  - tunnel
  - log tail
- Deterministic base URL handoff to mobile

## Non-goals (for now)
- Production-grade tunnel uptime
- Public deployment

## Rules
- Keep logs in /tmp with rotation strategy later
- Never commit secrets
