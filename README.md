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

| Service | Repo | Purpose |
|---------|------|---------|
| `lyra_telegram` | [Roxabi/lyra](https://github.com/Roxabi/lyra) | AI agent — Telegram adapter |
| `lyra_discord` | [Roxabi/lyra](https://github.com/Roxabi/lyra) | AI agent — Discord adapter |
| `voicecli_tts` | [Roxabi/voiceCLI](https://github.com/Roxabi/voiceCLI) | TTS daemon (Qwen, zero-latency) |
| `voicecli_stt` | [Roxabi/voiceCLI](https://github.com/Roxabi/voiceCLI) | STT daemon (Whisper, live dictation) |

## One-shot setup

```bash
# 1. Clone this repo
git clone git@github.com:Roxabi/lyra-stack.git ~/projects/lyra-stack

# 2. Clone and register each project
git clone git@github.com:Roxabi/lyra.git ~/projects/lyra
git clone git@github.com:Roxabi/voiceCLI.git ~/projects/voiceCLI

cd ~/projects/lyra    && uv sync && make register
cd ~/projects/voiceCLI && uv sync && make register

# 3. Start everything
cd ~/projects/lyra-stack && make start

# 4. Verify
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

## How it works

`conf.d/` contains only symlinks — each project repo owns its supervisor config and logs.
`make register` in any project creates the symlink and signals supervisord to pick it up.

```
~/projects/lyra-stack/conf.d/
  lyra_telegram.conf → ~/projects/lyra/supervisor/conf.d/lyra_telegram.conf
  lyra_discord.conf  → ~/projects/lyra/supervisor/conf.d/lyra_discord.conf
  voicecli_tts.conf  → ~/projects/voiceCLI/supervisor/conf.d/voicecli_tts.conf
  voicecli_stt.conf  → ~/projects/voiceCLI/supervisor/conf.d/voicecli_stt.conf
```

See [`docs/supervisor-pattern.md`](docs/supervisor-pattern.md)
for the full pattern and how to add new services.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for dev setup, commit format, and PR process.

## License

MIT
