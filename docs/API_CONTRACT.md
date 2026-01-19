# IRIDA — AI API Contract

## Base
- Base URL: configurable
- Health: `GET|HEAD /health` → `200 {"status":"ok"}`

## Analyze
### Request
`POST /analyze-eye` multipart/form-data

Fields:
- `file` (required) image/jpeg (or png)
- `eye` (required) "left" | "right"
- `exam_id` (required) string
- `age` (required) int
- `gender` (required) "M" | "F"
- Optional: `locale`, `task` (reserved)

### Response 200 JSON
- `status`: "ok"
- `api_version`: "1.0"
- `exam_id`: string
- `eye`: "left"|"right"
- `age`: int
- `gender`: "M"|"F"
- `quality`: float 0..1
- `zones`: [{name, score, note}]
- `took_ms`: int
