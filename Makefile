SUPERVISORCTL := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/supervisorctl.sh
SUPERVISOR_START := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/start.sh
SUPERVISOR_DIR := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SUPERVISOR_PID := $(SUPERVISOR_DIR)supervisord.pid

define ensure_supervisor
	@if [ ! -f "$(SUPERVISOR_PID)" ] || ! kill -0 $$(cat "$(SUPERVISOR_PID)" 2>/dev/null) 2>/dev/null; then \
		echo "supervisord not running, starting..."; \
		$(SUPERVISOR_START); \
	fi
endef

# ── Parse: make <service> <action> ───────────────────────────────────────────

ifneq (,$(filter lyra stt tts,$(firstword $(MAKECMDGOALS))))
  SVC_CMD := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq (,$(SVC_CMD))
    $(eval $(SVC_CMD):;@:)
  endif
endif

# ── Targets ───────────────────────────────────────────────────────────────────

.PHONY: start status ps lyra stt tts help

help:
	@echo "Usage: make <target> [action]"
	@echo ""
	@echo "  start            start supervisord + all services"
	@echo "  status           status of all services"
	@echo ""
	@echo "  lyra             lyra status"
	@echo "  lyra start|stop|reload|logs|errlogs"
	@echo ""
	@echo "  stt              voicecli_stt status"
	@echo "  stt start|reload|stop|logs|errlogs"
	@echo ""
	@echo "  tts              voicecli_tts status"
	@echo "  tts start|reload|stop|logs|errlogs"

.DEFAULT_GOAL := help

start:
	$(SUPERVISOR_START)

status ps:
	$(ensure_supervisor)
	$(SUPERVISORCTL) status

lyra:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart lyra
else ifeq ($(SVC_CMD),logs)
	tail -f $(HOME)/projects/lyra/supervisor/logs/lyra.log
else ifeq ($(SVC_CMD),errlogs)
	tail -f $(HOME)/projects/lyra/supervisor/logs/lyra_error.log
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop lyra
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start lyra
else ifeq ($(SVC_CMD),status)
	$(SUPERVISORCTL) status lyra
else
	$(SUPERVISORCTL) status lyra
endif

stt:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart voicecli_stt
else ifeq ($(SVC_CMD),logs)
	tail -f $(HOME)/projects/voiceCLI/supervisor/logs/voicecli_stt.log
else ifeq ($(SVC_CMD),errlogs)
	tail -f $(HOME)/projects/voiceCLI/supervisor/logs/voicecli_stt_error.log
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop voicecli_stt
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start voicecli_stt
else ifeq ($(SVC_CMD),status)
	$(SUPERVISORCTL) status voicecli_stt
else
	$(SUPERVISORCTL) status voicecli_stt
endif

tts:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart voicecli_tts
else ifeq ($(SVC_CMD),logs)
	tail -f $(HOME)/projects/voiceCLI/supervisor/logs/voicecli_tts.log
else ifeq ($(SVC_CMD),errlogs)
	tail -f $(HOME)/projects/voiceCLI/supervisor/logs/voicecli_tts_error.log
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop voicecli_tts
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start voicecli_tts
else ifeq ($(SVC_CMD),status)
	$(SUPERVISORCTL) status voicecli_tts
else
	$(SUPERVISORCTL) status voicecli_tts
endif
