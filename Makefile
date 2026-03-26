SUPERVISORCTL   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/supervisorctl.sh
SUPERVISOR_START := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/start.sh
SUPERVISOR_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SUPERVISOR_PID  := $(SUPERVISOR_DIR)supervisord.pid
MACHINE1        := $(or $(shell grep '^MACHINE1_HOST=' .env 2>/dev/null | cut -d= -f2),mickael@192.168.1.16)
MACHINE1_STACK  := $(or $(shell grep '^MACHINE1_STACK_DIR=' .env 2>/dev/null | cut -d= -f2),~/projects/lyra-stack)

define ensure_supervisor
	@if [ ! -f "$(SUPERVISOR_PID)" ] || ! kill -0 $$(cat "$(SUPERVISOR_PID)" 2>/dev/null) 2>/dev/null; then \
		echo "supervisord not running, starting..."; \
		$(SUPERVISOR_START) > /dev/null; \
	fi
endef

# ── Parse: make <service> <action> ───────────────────────────────────────────

IS_SVC_ACTION :=
ifneq (,$(filter lyra stt tts telegram discord diagrams,$(firstword $(MAKECMDGOALS))))
  SVC_CMD := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq (,$(SVC_CMD))
    IS_SVC_ACTION := 1
    $(eval $(SVC_CMD):;@:)
  endif
endif

# ── Targets ───────────────────────────────────────────────────────────────────

.PHONY: setup start stop status ps lyra stt tts telegram discord diagrams deploy help

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
	@echo "  diagrams start|stop|reload|logs|errlogs|status|sync|pull|push|du"
	@echo ""
	@echo "  deploy           git pull + rsync ~/.agent/ to production"
	@echo ""
	@echo "  Set LYRA_STACK_DIR to override hub location (default: ~/projects/lyra-stack)"

setup:
	@python3 scripts/setup.py $(ARGS)

ifndef IS_SVC_ACTION
start:
	$(SUPERVISOR_START)

stop:
	$(ensure_supervisor)
	$(SUPERVISORCTL) stop all
	@kill $$(cat "$(SUPERVISOR_PID)") 2>/dev/null || true

status ps:
	$(ensure_supervisor)
	$(SUPERVISORCTL) status
endif

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

diagrams:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart diagrams
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f diagrams
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f diagrams stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop diagrams
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start diagrams
else ifeq ($(SVC_CMD),push)
	@echo "── push local → Drive ──"
	rclone copy ~/.agent/ SyncLyra:agent-archive/ \
		--exclude "__pycache__/**" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		-v
else ifeq ($(SVC_CMD),pull)
	@echo "── pull Drive → local ──"
	rclone copy SyncLyra:agent-archive/ ~/.agent/ \
		--exclude "__pycache__/**" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		-v
else ifeq ($(SVC_CMD),sync)
	@echo "── push local → Drive ──"
	rclone copy ~/.agent/ SyncLyra:agent-archive/ \
		--exclude "__pycache__/**" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		-v
	@echo "── pull Drive → local ──"
	rclone copy SyncLyra:agent-archive/ ~/.agent/ \
		--exclude "__pycache__/**" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		-v
else ifeq ($(SVC_CMD),du)
	@du -sh ~/.agent/*/
else
	$(SUPERVISORCTL) status diagrams
endif

deploy:
	@echo "Deploying to production ($(MACHINE1))..."
	@echo "── git pull ──"
	@ssh $(MACHINE1) "cd $(MACHINE1_STACK) && git pull"
	@echo "── rsync ~/.agent/ ──"
	@rsync -avz \
		--exclude "__pycache__/" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		~/.agent/ $(MACHINE1):~/.agent/
	@echo "Done."
