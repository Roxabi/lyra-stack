# lyra-stack

One-command setup for the full Lyra infrastructure on a new machine.

Manages all background services (Lyra agent, TTS daemon, STT daemon) through a single
[supervisord](http://supervisord.org/) instance. Each service is owned by its project repo —
this repo is just the runtime hub that holds them together.

## What's included

| Service | Repo | Purpose |
|---------|------|---------|
| `lyra` | [Roxabi/lyra](https://github.com/Roxabi/lyra) | AI agent (Telegram + Discord) |
| `voicecli_tts` | [Roxabi/voiceCLI](https://github.com/Roxabi/voiceCLI) | TTS daemon (Qwen, zero-latency) |
| `voicecli_stt` | [Roxabi/voiceCLI](https://github.com/Roxabi/voiceCLI) | STT daemon (Whisper, live dictation) |

## One-shot setup

```bash
# 1. Clone this repo
git clone git@github.com:Roxabi/lyra-stack.git ~/lyra-stack

# 2. Clone and register each project
git clone git@github.com:Roxabi/lyra.git ~/projects/lyra
git clone git@github.com:Roxabi/voiceCLI.git ~/projects/voiceCLI

cd ~/projects/lyra    && uv sync && make register
cd ~/projects/voiceCLI && uv sync && make register

# 3. Start everything
cd ~/lyra-stack && make start

# 4. Verify
make ps
```

## Daily commands

```bash
cd ~/lyra-stack

make ps                  # status of all services

make lyra                # lyra status
make lyra reload         # restart lyra
make lyra logs           # tail stdout
make lyra errors         # tail stderr

make tts                 # tts status
make tts reload          # restart tts

make stt                 # stt status
make stt reload          # restart stt
```

## How it works

`conf.d/` contains only symlinks — each project repo owns its supervisor config and logs.
`make register` in any project creates the symlink and signals supervisord to pick it up.

```
~/lyra-stack/conf.d/
  lyra.conf         → ~/projects/lyra/supervisor/conf.d/lyra.conf
  voicecli_tts.conf → ~/projects/voiceCLI/supervisor/conf.d/voicecli_tts.conf
  voicecli_stt.conf → ~/projects/voiceCLI/supervisor/conf.d/voicecli_stt.conf
```

See [`~/projects/supervisor-pattern.md`](https://github.com/Roxabi/lyra/blob/main/docs/supervisor-pattern.md)
for the full pattern and how to add new services.
