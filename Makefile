SUPERVISORCTL   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/supervisorctl.sh
SUPERVISOR_START := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/start.sh
SUPERVISOR_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SUPERVISOR_PID  := $(SUPERVISOR_DIR)supervisord.pid

define ensure_supervisor
	@if [ ! -f "$(SUPERVISOR_PID)" ] || ! kill -0 $$(cat "$(SUPERVISOR_PID)" 2>/dev/null) 2>/dev/null; then \
		echo "supervisord not running, starting..."; \
		$(SUPERVISOR_START); \
	fi
endef

# ── Parse: make <service> <action> ───────────────────────────────────────────

ifneq (,$(filter lyra stt tts telegram discord,$(firstword $(MAKECMDGOALS))))
  SVC_CMD := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq (,$(SVC_CMD))
    $(eval $(SVC_CMD):;@:)
  endif
endif

# ── Targets ───────────────────────────────────────────────────────────────────

.PHONY: setup start stop status ps lyra stt tts telegram discord help

.DEFAULT_GOAL := help

help:
	@echo "Usage: make <target> [action]"
	@echo ""
	@echo "  setup            clone + register modules, start supervisord"
	@echo "  start            start supervisord (idempotent)"
	@echo "  stop             stop all services + supervisord"
	@echo "  ps               status of all services"
	@echo ""
	@echo "  lyra     start|stop|reload|logs|errlogs|status"
	@echo "  tts      start|stop|reload|logs|errlogs|status"
	@echo "  stt      start|stop|reload|logs|errlogs|status"
	@echo "  telegram start|stop|reload|logs|errlogs|status"
	@echo "  discord  start|stop|reload|logs|errlogs|status"
	@echo ""
	@echo "  Set LYRA_STACK_DIR to override hub location (default: ~/projects/lyra-stack)"

setup:
	@python3 scripts/setup.py $(ARGS)

start:
	$(SUPERVISOR_START)

stop:
	$(ensure_supervisor)
	$(SUPERVISORCTL) stop all
	@kill $$(cat "$(SUPERVISOR_PID)") 2>/dev/null || true

status ps:
	$(ensure_supervisor)
	$(SUPERVISORCTL) status

lyra:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart lyra_telegram
	$(SUPERVISORCTL) restart lyra_discord
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f lyra_telegram
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f lyra_telegram stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop lyra_telegram
	$(SUPERVISORCTL) stop lyra_discord
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start lyra_telegram
	$(SUPERVISORCTL) start lyra_discord
else
	$(SUPERVISORCTL) status lyra_telegram
	$(SUPERVISORCTL) status lyra_discord
endif

telegram:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart lyra_telegram
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f lyra_telegram
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f lyra_telegram stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop lyra_telegram
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start lyra_telegram
else
	$(SUPERVISORCTL) status lyra_telegram
endif

discord:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart lyra_discord
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f lyra_discord
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f lyra_discord stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop lyra_discord
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start lyra_discord
else
	$(SUPERVISORCTL) status lyra_discord
endif

stt:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart voicecli_stt
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f voicecli_stt
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f voicecli_stt stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop voicecli_stt
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start voicecli_stt
else
	$(SUPERVISORCTL) status voicecli_stt
endif

tts:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart voicecli_tts
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f voicecli_tts
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f voicecli_tts stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop voicecli_tts
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start voicecli_tts
else
	$(SUPERVISORCTL) status voicecli_tts
endif
