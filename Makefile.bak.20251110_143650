PORT ?= 8010
PIDFILE := /tmp/iris_ai.$(PORT).pid
LOGFILE := /tmp/iris_ai.$(PORT).log

.PHONY: start stop restart status logs health smoke

start:
	@if lsof -ti tcp:$(PORT) >/dev/null 2>&1; then echo RUNNING; exit 0; fi; \
	nohup env PORT=$(PORT) bash scripts/run_server_prod.sh >/dev/null 2>&1 & sleep 1; \
	P=$$(lsof -ti tcp:$(PORT) | head -n1); echo $$P > $(PIDFILE); \
	test -n "$$P" && echo STARTED $$P || (echo START FAILED && exit 1)

stop:
	@sh -lc 'test -f $(PIDFILE) && P=$$(cat $(PIDFILE)) || P=""; test -n "$$P" && kill -TERM $$P || true'
	@sleep 0.5
	@lsof -ti tcp:$(PORT) | xargs kill -9 2>/dev/null || true
	@rm -f /tmp/iris_ai.$(PORT).pid /tmp/iris_ai.$(PORT).lock
	@echo STOPPED

restart: stop start

status:
	@lsof -iTCP:$(PORT) -sTCP:LISTEN -n -P || true

logs:
	@touch $(LOGFILE)
	@tail -n 200 -f $(LOGFILE)

health:
	@curl -fsS http://127.0.0.1:$(PORT)/health | python3 -m json.tool

smoke:
	@PORT=$(PORT) bash scripts/smoke.sh
