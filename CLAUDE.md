# ~/lyra-stack — Lyra Infrastructure

Central supervisord instance for the **local** machine (ROXABITOWER, WSL2, RTX 5070 Ti).
Manages all background services that support Lyra and its ecosystem.

## Services

| Program | Command | Purpose |
|---------|---------|---------|
| `lyra` | `python -m lyra` | Lyra AI agent (Telegram + Discord) |
| `voicecli_tts` | `voicecli serve --engine qwen-fast` | TTS daemon — keeps Qwen model warm in VRAM for zero-latency speech generation |
| `voicecli_stt` | `voicecli stt-serve` | STT daemon — keeps faster-whisper loaded for fast dictation via `voicecli dictate` |

## Layout

```
~/lyra-stack/
  supervisord.conf      — daemon config (socket, logs, includes conf.d)
  conf.d/               — symlinks only, each project owns its conf
    lyra.conf           → ~/projects/lyra/supervisor/conf.d/lyra.conf
    voicecli_tts.conf   → ~/projects/voiceCLI/supervisor/conf.d/voicecli_tts.conf
    voicecli_stt.conf   → ~/projects/voiceCLI/supervisor/conf.d/voicecli_stt.conf
  scripts/
    start.sh            — start supervisord (idempotent)
    supervisorctl.sh    — supervisorctl wrapper (correct socket path)
  logs/                 — supervisord own logs only
  Makefile              — control interface (see below)
```

## Commands

```bash
cd ~/lyra-stack

make start           # start supervisord + all services (idempotent)
make ps              # status of all services

make lyra            # show lyra status
make lyra start|reload|stop|logs|errlogs

make tts             # show tts status
make tts start|reload|stop|logs|errlogs

make stt             # show stt status
make stt start|reload|stop|logs|errlogs
```

## Adding a New Service

1. Add `supervisor/conf.d/<program>.conf` to the project repo (logs → project's `supervisor/logs/`)
2. Add `supervisor/scripts/supervisorctl.sh` pointing to `$HOME/lyra-stack/supervisord.conf`
3. Add `supervisor/logs/` to `.gitignore`
4. Add `make register` and service targets to the project Makefile
5. Run `make register` — creates the symlink and signals supervisord

See `~/projects/supervisor-pattern.md` for the full pattern.

## Sockets

| Daemon | Socket |
|--------|--------|
| TTS | `~/.local/share/voicecli/daemon.sock` |
| STT | `~/.local/share/voicecli/stt-daemon.sock` |
