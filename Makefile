.PHONY: start stop status logs smoke health restart
PORT?=8010
PID=/tmp/iris_ai.$(PORT).pid
LOG=/tmp/iris_ai.$(PORT).log
start:
	nohup env PORT=$(PORT) bash scripts/run_server_prod.sh >> $(LOG) 2>&1 &
	sleep 0.8
	sh -lc 'P=$$(lsof -ti tcp:$(PORT) | head -n1); echo $$P > $(PID); test -n "$$P" && echo STARTED $$P || echo START FAILED'
status:
	sh -lc 'test -f $(PID) && P=$$(cat $(PID)); test -n "$$P" && ps -p $$P -o pid,comm= || echo STOPPED'
stop:
	sh -lc 'test -f $(PID) && P=$$(cat $(PID)) || P=""; test -n "$$P" && kill -TERM $$P || true'
	sleep 0.5
	lsof -ti tcp:$(PORT) | xargs kill -9 2>/dev/null || true
	rm -f $(PID)
logs:
	tail -n 200 -f $(LOG)
smoke:
	PORT=$(PORT) bash scripts/smoke.sh
health:
	curl -fsS http://127.0.0.1:$(PORT)/health | python3 -m json.tool
restart:
	$(MAKE) stop PORT=$(PORT)
	$(MAKE) start PORT=$(PORT)
