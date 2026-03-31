# lyra-stack

[![CI](https://github.com/Roxabi/lyra-stack/actions/workflows/ci.yml/badge.svg)](https://github.com/Roxabi/lyra-stack/actions)

One-command setup for the full Lyra infrastructure on a new machine.

Manages all background services (Lyra agent, TTS daemon, STT daemon) through a single
[supervisord](http://supervisord.org/) instance. Each service is owned by its project repo —
this repo is just the runtime hub that holds them together.

## Why

Running multiple AI services (agent, TTS, STT) means managing several long-lived processes across multiple repos. Without a shared supervisor, each service needs its own restart logic, log plumbing, and startup order — and a machine reboot means manually restarting everything.

lyra-stack solves this with a single supervisord instance. Each project repo owns its config; this hub just wires them together. One `make start` brings everything up, and any project can register itself with `make register`. A systemd user unit with linger ensures everything auto-starts on boot — no login session required.

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

**Claude Code plugins (installed by `make setup`):**

| Plugin | Marketplace | Kind | Purpose |
|--------|------------|------|---------|
| `web-intel` | `roxabi-marketplace` | mandatory | URL scraping & content analysis |
| `agent-browser` | `agent-browser` | mandatory | Headless browser for auth/interactive pages |
| `lyra-send` | `lyra-marketplace` | mandatory | Proactive messaging via Telegram & Discord |
| `refine-agent` | `lyra-marketplace` | mandatory | Agent profile management |
| `voice-cli` | `voicecli-marketplace` | conditional | VoiceCLI TTS/STT integration (if voiceCLI installed) |
| `dev-core` | `roxabi-marketplace` | optional | Full dev workflow (frame→spec→plan→ship) |
| `visual-explainer` | `roxabi-marketplace` | optional | HTML diagrams & data visualizations |
| `compress` | `roxabi-marketplace` | optional | Compact agent/skill definitions, save tokens |

## One-shot setup

```bash
# 1. Provision the machine (system packages, uv, supervisord, Claude CLI, etc.)
curl -fsSL https://raw.githubusercontent.com/Roxabi/lyra-stack/main/scripts/provision.sh | bash

# 2. Clone this repo and run setup
#    Installs lyra (core), prompts for optional modules (voiceCLI, diagrams, etc.)
#    and installs Claude Code plugins (mandatory + prompted optional)
git clone git@github.com:Roxabi/lyra-stack.git ~/projects/lyra-stack
cd ~/projects/lyra-stack && make setup

# 3. Configure (fill in user IDs + store bot tokens)
nano ~/projects/lyra/config.toml
lyra bot add

# 4. Authenticate Claude CLI
claude

# 5. Enable auto-start on boot
systemctl --user enable lyra-stack.service
loginctl enable-linger $USER

# 6. Verify
make ps
```

## Daily commands

All commands run from `~/projects/lyra-stack`.

### Global

| Command | Description |
|---------|-------------|
| `make start` | Start supervisord + all services (idempotent) |
| `make ps` | Status of all services |
| `systemctl --user status lyra-stack` | systemd unit status |

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

Exploration artifacts (brand iterations, diagram drafts, visual explorations) live in `~/.agent/` (data only). Tooling lives in `lyra-stack/diagrams/` (git-tracked). Latest versions are tagged with the `latest` badge in diagram meta. Backed up to Google Drive via rclone.

| Command | Description |
|---------|-------------|
| `make diagrams` | Show gallery server status |
| `make diagrams start` | Start gallery server on :8080 |
| `make diagrams push` | Push `~/.agent/` to Google Drive |
| `make diagrams pull` | Pull Google Drive to `~/.agent/` |
| `make diagrams sync` | Push then pull (bidirectional) |
| `make diagrams build` | Regenerate manifest + assemble `_dist/` |
| `make diagrams deploy` | Build + deploy to Cloudflare Pages |
| `make diagrams deploy-prod` | Rsync `~/.agent/` to production (with `--delete`) |
| `make diagrams du` | Disk usage per project |

## Multi-machine setup

NATS is the message broker for pub/sub communication between the Lyra hub and workers (future use — Slice A3+).

NATS is **opt-in** — `provision.sh` does not install it. Single-machine setups work without NATS.
To enable it on machines that participate in multi-machine mode:

```bash
# Run after provision.sh + cloning lyra-stack
cd ~/projects/lyra-stack && make nats-install
```

This installs the NATS binary, system user, config, systemd unit, lyra-stack ordering drop-in,
and UFW rule (port 4222, LAN-only). Idempotent — safe to run multiple times.

After `make nats-install`, complete the TLS + nkey setup:

```bash
sudo ~/projects/lyra-stack/scripts/gen-nats-certs.sh   # TLS CA + server cert
sudo ~/projects/lyra-stack/scripts/gen-nats-nkeys.sh   # nkey pairs → /etc/nats/nkeys/auth.conf
sudo systemctl start nats.service
sudo systemctl status nats.service
```

NATS runs as a **systemd system service** (`nats.service`), independent of supervisord.
Auth uses **nkey** public-key authentication. Transport is **TLS 1.3** (self-signed CA).

```bash
# Daily control
sudo systemctl status|start|stop|restart nats
sudo journalctl -u nats -f
```

Config lives in `nats/nats.conf` (installed to `/etc/nats/nats.conf` by `make nats-install`).
Port 4222 is LAN-only (`192.168.1.0/24`).
The `lyra-stack.service` user unit starts after `nats.service` via a systemd drop-in (installed by `make nats-install`).

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
