# Supervisor Pattern — Roxabi Projects

Standard for managing daemons across all projects. Every project that runs background
services follows this contract so they can work standalone **and** be centralized.

## Architecture: Symlink Federation

One supervisord instance at `~/projects/lyra-stack/` manages all daemons.
Its `conf.d/` contains **only symlinks** — each project repo owns its configs.

```
~/projects/lyra-stack/                              ← single supervisord (the hub)
  supervisord.conf                         ← [include] conf.d/*.conf
  conf.d/
    lyra_telegram.conf → ~/projects/lyra/supervisor/conf.d/lyra_telegram.conf
    lyra_discord.conf  → ~/projects/lyra/supervisor/conf.d/lyra_discord.conf
    voicecli_tts.conf  → ~/projects/voiceCLI/supervisor/conf.d/voicecli_tts.conf
    voicecli_stt.conf  → ~/projects/voiceCLI/supervisor/conf.d/voicecli_stt.conf
  scripts/
    start.sh
    supervisorctl.sh

~/.local/state/
  lyra-stack/logs/                         ← supervisord + diagrams logs
  lyra/logs/                               ← lyra process + app logs
  voicecli/logs/                           ← voicecli process logs

~/projects/<project>/supervisor/
  conf.d/<program>.conf                    ← source of truth (checked into git)
  scripts/
    run.sh                                 ← sources .env, then exec's the daemon
    supervisorctl.sh                       ← delegates to ~/projects/lyra-stack/
```

**Rule:** configs live in the project repo. `~/projects/lyra-stack/conf.d/` never contains real files.

---

## LYRA_STACK_DIR Convention

The hub location defaults to `~/projects/lyra-stack/` but is overridable via the
`LYRA_STACK_DIR` environment variable. All scripts and Makefiles respect this variable,
so the hub can live elsewhere on machines with a different layout.

```bash
# Override hub location
export LYRA_STACK_DIR=/opt/lyra-stack
make register          # uses $LYRA_STACK_DIR instead of ~/projects/lyra-stack
```

---

## Per-project Contract

Every project with daemons must have:

### 1. `supervisor/conf.d/<program>.conf`
The supervisord program definition. Checked into git. Points to the run wrapper script.
Logs write to `~/.local/state/<app>/logs/` (XDG Base Directory spec).

```ini
[program:myproject]
command=%(ENV_HOME)s/projects/myproject/supervisor/scripts/run.sh
directory=%(ENV_HOME)s/projects/myproject
autostart=true
autorestart=true
startsecs=5
startretries=3
stopwaitsecs=10
stopasgroup=true
killasgroup=true
stdout_logfile=%(ENV_HOME)s/.local/state/myproject/logs/myproject.log
stdout_logfile_maxbytes=10MB
stdout_logfile_backups=3
stderr_logfile=%(ENV_HOME)s/.local/state/myproject/logs/myproject_error.log
stderr_logfile_maxbytes=5MB
stderr_logfile_backups=3
```

### 2. `supervisor/scripts/run.sh`
Sources `.env` before launching the daemon — keeps secrets out of conf files.

```bash
#!/usr/bin/env bash
set -a
[ -f "$HOME/projects/myproject/.env" ] && source "$HOME/projects/myproject/.env"
set +a
exec "$HOME/projects/myproject/.venv/bin/python" -m myproject
```

### 3. `supervisor/scripts/supervisorctl.sh`
Thin delegate — always points to the global supervisor socket.

```bash
#!/usr/bin/env bash
STACK_DIR="${LYRA_STACK_DIR:-$HOME/projects/lyra-stack}"
exec supervisorctl -c "$STACK_DIR/supervisord.conf" "$@"
```

### 4. Log directory — XDG-compliant
Logs write to `~/.local/state/<app>/logs/` per the XDG Base Directory spec.
The `make register` target creates the directory. No `.gitignore` entry needed since
logs are outside the project tree.

### 5. `make register` — idempotent, run once on new machine
Creates the symlink in `~/projects/lyra-stack/conf.d/` and signals supervisord to pick it up.

```makefile
LYRA_STACK_DIR ?= $(HOME)/projects/lyra-stack

register:
	@echo "Registering myproject with global supervisor..."
	@if [ ! -d "$(LYRA_STACK_DIR)" ]; then \
		echo "Error: $(LYRA_STACK_DIR) not found. Set up the global supervisor first."; \
		exit 1; \
	fi
	@mkdir -p "$(HOME)/.local/state/myproject/logs"
	@ln -sf "$(abspath supervisor/conf.d/myproject.conf)" \
		"$(LYRA_STACK_DIR)/conf.d/myproject.conf"
	@if [ -S "$(LYRA_STACK_DIR)/supervisor.sock" ]; then \
		$(LYRA_STACK_DIR)/scripts/supervisorctl.sh reread && \
		$(LYRA_STACK_DIR)/scripts/supervisorctl.sh update; \
	fi
	@echo "Done. Run 'make myproject' to start."
```

Projects without daemons (e.g. imageCLI) set `register = false` in `stack.toml` to skip
this step during `make setup`.

### 6. `make <service> [action]` — standard targets
Each project exposes its services with consistent commands:

```bash
make myproject           # start (ensure global supervisor running, then start program)
make myproject stop      # stop
make myproject reload    # restart
make myproject logs      # tail stdout
make myproject errors    # tail stderr
make myproject status    # supervisorctl status
```

---

## Checks before `make <service>` runs

Every start target performs these checks in order:

```
1. $LYRA_STACK_DIR (default: ~/projects/lyra-stack/) exists?
   → no: error "Set up ~/projects/lyra-stack first (see ~/projects/supervisor-pattern.md)"

2. $LYRA_STACK_DIR/conf.d/<program>.conf symlink exists?
   → no: auto-create it (idempotent registration), then reread/update

3. Global supervisord running?
   → no: start it via $LYRA_STACK_DIR/scripts/start.sh

4. Stale local supervisord for this project running?
   → yes: kill it, clean up PID + sock files

5. Delegate to $LYRA_STACK_DIR/scripts/supervisorctl.sh
```

---

## Setting up a new machine

```bash
# 1. Clone the global supervisor
git clone git@github.com:Roxabi/lyra-stack.git ~/projects/lyra-stack
cd ~/projects/lyra-stack && make start

# 2. Clone and register each module (or use setup to do it all at once)
cd ~/projects/lyra-stack && make setup

# 3. Verify all programs are loaded
cd ~/projects/lyra-stack && make ps
```

---

## Adding a new project

1. Add `supervisor/conf.d/<program>.conf` (use the template above — logs → `~/.local/state/<app>/logs/`)
2. Add `supervisor/scripts/run.sh` (sources `.env`, execs the daemon)
3. Add `supervisor/scripts/supervisorctl.sh` (copy from any existing project)
4. Add `make register` and `make <service>` targets to the project Makefile
5. Add the module to `~/projects/lyra-stack/stack.toml`
6. Run `make register` on each machine
7. Add the program to the table in `~/projects/CLAUDE.md`

---

## Global supervisor Makefile convention

`~/projects/lyra-stack/Makefile` exposes delegate targets for convenience:

```bash
make lyra              # lyra_telegram + lyra_discord status (or: start|stop|reload|logs|errlogs)
make telegram          # lyra_telegram only (same actions)
make discord           # lyra_discord only (same actions)
make tts               # voicecli_tts status (same actions)
make stt               # voicecli_stt status (same actions)
make ps                # status of all programs
make setup             # clone + register all modules, start supervisord
make setup ARGS=--all  # include optional modules
```

---

## Current registry

| Program | Project | Config |
|---------|---------|--------|
| `lyra_telegram` | `~/projects/lyra` | `lyra/supervisor/conf.d/lyra_telegram.conf` |
| `lyra_discord` | `~/projects/lyra` | `lyra/supervisor/conf.d/lyra_discord.conf` |
| `voicecli_tts` | `~/projects/voiceCLI` | `voiceCLI/supervisor/conf.d/voicecli_tts.conf` |
| `voicecli_stt` | `~/projects/voiceCLI` | `voiceCLI/supervisor/conf.d/voicecli_stt.conf` |
| `diagrams` | `~/projects/lyra-stack` | `lyra-stack/diagrams/conf.d/diagrams.conf` |
