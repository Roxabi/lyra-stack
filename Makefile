SUPERVISORCTL   := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/supervisorctl.sh
SUPERVISOR_START := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))scripts/start.sh
SUPERVISOR_DIR  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SUPERVISOR_PID  := $(SUPERVISOR_DIR)supervisord.pid
DEPLOY_HOST     := $(shell grep '^DEPLOY_HOST=' .env 2>/dev/null | cut -d= -f2)
DEPLOY_STACK    := $(or $(shell grep '^DEPLOY_STACK_DIR=' .env 2>/dev/null | cut -d= -f2),~/projects/lyra-stack)
FORGE_DIR       ?= $(HOME)/.roxabi/forge
IDNA_DIR        ?= $(HOME)/.roxabi/idna

# Common excludes for rclone sync (Google Drive) — skip tooling (symlinks to repo), build output, caches
RCLONE_EXCLUDES := \
	--exclude "__pycache__/**" \
	--exclude "*.pyc" \
	--exclude ".DS_Store" \
	--exclude ".sync.log" \
	--exclude "_dist/**" \
	--exclude "*.py" \
	--exclude "/build.sh" \
	--exclude "/index.html" \
	--exclude "/manifest.json"

define ensure_supervisor
	@if [ ! -f "$(SUPERVISOR_PID)" ] || ! kill -0 $$(cat "$(SUPERVISOR_PID)" 2>/dev/null) 2>/dev/null; then \
		echo "supervisord not running, starting..."; \
		$(SUPERVISOR_START) > /dev/null; \
	fi
endef

# ── Parse: make <service> <action> ───────────────────────────────────────────

IS_SVC_ACTION :=
ifneq (,$(filter lyra stt tts telegram discord forge monitor idna,$(firstword $(MAKECMDGOALS))))
  SVC_CMD := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq (,$(SVC_CMD))
    IS_SVC_ACTION := 1
    $(eval $(SVC_CMD):;@:)
  endif
endif

# ── Targets ───────────────────────────────────────────────────────────────────

.PHONY: setup start stop status ps lyra stt tts telegram discord forge monitor idna deploy nats-install help

.DEFAULT_GOAL := help

help:
	@echo "Usage: make <target> [action]"
	@echo ""
	@echo "  setup            clone + register modules, start supervisord"
	@echo "  start            start supervisord (idempotent)"
	@echo "  stop             stop all services + supervisord"
	@echo "  ps               status of all services"
	@echo ""
	@echo "  lyra     start|stop|reload|logs|errlogs|status  (hub + telegram + discord)"
	@echo "  tts      start|stop|reload|logs|errlogs|status"
	@echo "  stt      start|stop|reload|logs|errlogs|status"
	@echo "  telegram start|stop|reload|logs|errlogs|status"
	@echo "  discord  start|stop|reload|logs|errlogs|status"
	@echo "  forge    start|stop|reload|logs|errlogs|status|sync|pull|push|du|build|deploy|deploy-prod"
	@echo "  idna     start|stop|reload|logs|errlogs|status|ls  (local only, never deployed)"
	@echo "  monitor  status|logs|run|enable|disable  (systemd timer, not supervisor)"
	@echo ""
	@echo "  deploy           git pull + rsync $(FORGE_DIR)/ to production"
	@echo "  nats-install     opt-in NATS server setup (binary, user, config, systemd)"
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
	$(SUPERVISORCTL) restart lyra_hub
	$(SUPERVISORCTL) restart lyra_telegram
	$(SUPERVISORCTL) restart lyra_discord
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f lyra_hub
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f lyra_hub stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop lyra_hub
	$(SUPERVISORCTL) stop lyra_telegram
	$(SUPERVISORCTL) stop lyra_discord
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start lyra_hub
	$(SUPERVISORCTL) start lyra_telegram
	$(SUPERVISORCTL) start lyra_discord
else
	$(SUPERVISORCTL) status lyra_hub
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

forge:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart forge
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f forge
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f forge stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop forge
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start forge
else ifeq ($(SVC_CMD),push)
	@echo "── push ~/.roxabi/ → Drive ──"
	rclone copy $(HOME)/.roxabi/ SyncLyra:roxabi/ $(RCLONE_EXCLUDES) -v
else ifeq ($(SVC_CMD),pull)
	@echo "── pull Drive → ~/.roxabi/ ──"
	rclone copy SyncLyra:roxabi/ $(HOME)/.roxabi/ $(RCLONE_EXCLUDES) -v
else ifeq ($(SVC_CMD),sync)
	@echo "── push ~/.roxabi/ → Drive ──"
	rclone copy $(HOME)/.roxabi/ SyncLyra:roxabi/ $(RCLONE_EXCLUDES) -v
	@echo "── pull Drive → ~/.roxabi/ ──"
	rclone copy SyncLyra:roxabi/ $(HOME)/.roxabi/ $(RCLONE_EXCLUDES) -v
else ifeq ($(SVC_CMD),build)
	@bash $(SUPERVISOR_DIR)forge/build.sh
else ifeq ($(SVC_CMD),deploy)
	@bash $(SUPERVISOR_DIR)forge/build.sh
	@echo "▸ Deploying to Cloudflare Pages…"
	@set -a; [ -f .env ] && . ./.env; set +a; CLOUDFLARE_ACCOUNT_ID=b5e90be971920ce406f7b679c4f1cd33 npx wrangler pages deploy $(FORGE_DIR)/_dist --project-name=diagrams --branch=main --commit-dirty=true
else ifeq ($(SVC_CMD),deploy-prod)
	@echo "── rsync $(FORGE_DIR)/ → production ──"
	@rsync -avz --delete \
		--exclude "__pycache__/" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		--exclude "_dist/" \
		--exclude "*.py" \
		--exclude "build.sh" \
		--exclude "manifest.json" \
		$(FORGE_DIR)/ $(DEPLOY_HOST):$(FORGE_DIR)/
	@echo "Done."
else ifeq ($(SVC_CMD),du)
	@du -sh $(FORGE_DIR)/*/
else
	$(SUPERVISORCTL) status forge
endif

idna:
	$(ensure_supervisor)
ifeq ($(SVC_CMD),reload)
	$(SUPERVISORCTL) restart idna
else ifeq ($(SVC_CMD),logs)
	$(SUPERVISORCTL) tail -f idna
else ifeq ($(SVC_CMD),errlogs)
	$(SUPERVISORCTL) tail -f idna stderr
else ifeq ($(SVC_CMD),stop)
	$(SUPERVISORCTL) stop idna
else ifeq ($(SVC_CMD),start)
	$(SUPERVISORCTL) start idna
else ifeq ($(SVC_CMD),ls)
	@ls $(IDNA_DIR)/
else
	$(SUPERVISORCTL) status idna
endif

monitor:
ifeq ($(SVC_CMD),status)
	@systemctl --user status lyra-monitor.timer lyra-monitor.service 2>&1 || true
	@echo ""
	@systemctl --user list-timers lyra-monitor.timer 2>/dev/null || true
else ifeq ($(SVC_CMD),logs)
	@journalctl --user -u lyra-monitor.service -f
else ifeq ($(SVC_CMD),run)
	@echo "Triggering manual monitoring run..."
	@systemctl --user start lyra-monitor.service
else ifeq ($(SVC_CMD),enable)
	@systemctl --user enable --now lyra-monitor.timer
	@echo "Monitor timer enabled."
else ifeq ($(SVC_CMD),disable)
	@systemctl --user disable --now lyra-monitor.timer
	@echo "Monitor timer disabled."
else
	@systemctl --user status lyra-monitor.timer 2>&1 || true
endif

nats-install:
	@bash $(SUPERVISOR_DIR)scripts/nats-install.sh

ifndef IS_SVC_ACTION
deploy:
	@echo "Deploying to production ($(DEPLOY_HOST))..."
	@echo "── git pull ──"
	@ssh $(DEPLOY_HOST) "cd $(DEPLOY_STACK) && git pull"
	@echo "── rsync $(FORGE_DIR)/ ──"
	@rsync -avz \
		--exclude "__pycache__/" \
		--exclude "*.pyc" \
		--exclude ".DS_Store" \
		--exclude ".sync.log" \
		--exclude "_dist/" \
		--exclude "*.py" \
		--exclude "build.sh" \
		--exclude "manifest.json" \
		$(FORGE_DIR)/ $(DEPLOY_HOST):$(FORGE_DIR)/
	@echo "Done."
endif
