.PHONY: ai-up ai-down ai-tail ios-run ios-clean ios-release test-cycle smoke

ai-up:
	@source .venv/bin/activate 2>/dev/null || true; \
	lsof -ti tcp:8010 | xargs kill -9 2>/dev/null || true; \
	rm -f /tmp/iris_ai.8010.pid; rm -rf /tmp/iris_ai.8010.lock; \
	: > /tmp/iris_ai.8010.log; \
	nohup python3 -m uvicorn iris_ai_server:app --host 0.0.0.0 --port 8010 >> /tmp/iris_ai.8010.log 2>&1 & \
	&& sleep 1 && curl -fsS http://127.0.0.1:8010/health | python3 -m json.tool

ai-down:
	@lsof -ti tcp:8010 | xargs kill -9 2>/dev/null || true; \
	echo "[AI] server stopped."

ai-tail:
	@tail -n 200 -f /tmp/iris_ai.8010.log

ios-clean:
	@pkill -f "flutter_tools.*(run|attach|logs)" 2>/dev/null || true; \
	pkill -f iproxy 2>/dev/null || true; \
	echo "[iOS] cleaned."

ios-run:
	@make ios-clean; \
	fvm flutter run -d 00008110-000958EE01C0401E \
	  --dart-define=AI_ENDPOINT=http://172.20.10.11:8010/analyze

ios-release:
	@fvm flutter build ios --release

test-cycle:
	@echo "=== FULL TEST CYCLE START ==="; \
	make ai-up; \
	make ios-run; \
	make ai-tail

smoke:
	@echo "[SMOKE] Sending L.jpg/R.jpg"; \
	curl -sS -o /tmp/smoke.json \
		-F exam_id=SMOKE-TEST \
		-F age=33 -F gender=male \
		-F left=@/var/tmp/L.jpg \
		-F right=@/var/tmp/R.jpg \
		http://127.0.0.1:8010/analyze \
		&& head -c 300 /tmp/smoke.json; echo
