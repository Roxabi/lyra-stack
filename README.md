# lyra-stack

[![CI](https://github.com/Roxabi/lyra-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/Roxabi/lyra-stack/actions)

One-command setup for the full Lyra infrastructure on a new machine.

Manages all background services (Lyra agent, TTS daemon, STT daemon) through a single
[supervisord](http://supervisord.org/) instance. Each service is owned by its project repo —
this repo is just the runtime hub that holds them together.

## Why

Running multiple AI services (agent, TTS, STT) means managing several long-lived processes across multiple repos. Without a shared supervisor, each service needs its own restart logic, log plumbing, and startup order — and a machine reboot means manually restarting everything.

lyra-stack solves this with a single supervisord instance. Each project repo owns its config; this hub just wires them together. One `make start` brings everything up, and any project can register itself with `make register`.

## What's included

**Core (always installed):**

| Service | Repo | Purpose |
|---------|------|---------|
| `lyra_telegram` | [Roxabi/lyra](https://github.com/Roxabi/lyra) | AI agent — Telegram adapter |
| `lyra_discord` | [Roxabi/lyra](https://github.com/Roxabi/lyra) | AI agent — Discord adapter |

**Optional (prompted during setup):**

| Service | Repo | Purpose | Requires |
|---------|------|---------|----------|
| `voicecli_tts` | [Roxabi/voiceCLI](https://github.com/Roxabi/voiceCLI) | TTS daemon (Qwen, zero-latency) | NVIDIA GPU |
| `voicecli_stt` | [Roxabi/voiceCLI](https://github.com/Roxabi/voiceCLI) | STT daemon (Whisper, live dictation) | NVIDIA GPU |
| `diagrams` | (built-in) | Diagrams gallery with live-reload | — |
| — | [Roxabi/imageCLI](https://github.com/Roxabi/imageCLI) | Image generation CLI | NVIDIA GPU |
| — | [Roxabi/roxabi-vault](https://github.com/Roxabi/roxabi-vault) | Knowledge vault | — |

## One-shot setup

```bash
# 1. Provision the machine (system packages, uv, supervisord, Claude CLI, etc.)
curl -fsSL https://raw.githubusercontent.com/Roxabi/lyra-stack/main/scripts/provision.sh | bash

# 2. Clone this repo and run setup
#    Installs lyra (core), then prompts for optional modules (voiceCLI, diagrams, etc.)
git clone git@github.com:Roxabi/lyra-stack.git ~/projects/lyra-stack
cd ~/projects/lyra-stack && make setup

# 3. Configure (fill in user IDs + store bot tokens)
nano ~/projects/lyra/config.toml
lyra bot add

# 4. Authenticate Claude CLI
claude

# 5. Verify
make ps
```

## Daily commands

All commands run from `~/projects/lyra-stack`.

### Global

| Command | Description |
|---------|-------------|
| `make start` | Start supervisord + all services (idempotent) |
| `make ps` | Status of all services |

### Per-service

Replace `<svc>` with `lyra` (both adapters), `telegram`, `discord`, `tts`, or `stt`.

| Command | Description |
|---------|-------------|
| `make <svc>` | Show service status |
| `make <svc> reload` | Restart service |
| `make <svc> logs` | Tail stdout |
| `make <svc> errors` | Tail stderr |
| `make <svc> stop` | Stop service |

### Diagrams & exploration artifacts

Exploration artifacts (brand iterations, diagram drafts, visual explorations) live in `~/.agent/<project>/`, outside git repos. Only finals are committed. Backed up to Google Drive via rclone.

| Command | Description |
|---------|-------------|
| `make diagrams` | Show gallery server status |
| `make diagrams start` | Start gallery server on :8080 |
| `make diagrams sync` | Sync `~/.agent/` to Google Drive |
| `make diagrams du` | Disk usage per project |
| `make deploy` | Git pull + rsync `~/.agent/` to production |

## How it works

`conf.d/` contains only symlinks — each project repo owns its supervisor config and logs.
`make register` in any project creates the symlink and signals supervisord to pick it up.

```
~/projects/lyra-stack/conf.d/
  lyra_telegram.conf → ~/projects/lyra/supervisor/conf.d/lyra_telegram.conf
  lyra_discord.conf  → ~/projects/lyra/supervisor/conf.d/lyra_discord.conf
  voicecli_tts.conf  → ~/projects/voiceCLI/supervisor/conf.d/voicecli_tts.conf
  voicecli_stt.conf  → ~/projects/voiceCLI/supervisor/conf.d/voicecli_stt.conf
  diagrams.conf      → ~/projects/lyra-stack/diagrams/conf.d/diagrams.conf
```

See [`docs/supervisor-pattern.md`](docs/supervisor-pattern.md)
for the full pattern and how to add new services.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, commit format, and PR process.

## License

MIT
