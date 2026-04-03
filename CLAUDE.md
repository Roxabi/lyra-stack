@.claude/stack.yml
@.claude/dev-core.md
@CLAUDE.local.md

# ~/projects/lyra-stack — Lyra Infrastructure

Central supervisord instance for the local machine.
Manages all background services that support Lyra and its ecosystem.
Managed by a **systemd user unit** (`lyra-stack.service`) with linger — auto-starts on boot.

## Services

| Program | Command | Purpose |
|---------|---------|---------|
| `lyra_telegram` | `python -m lyra --adapter telegram` | Lyra AI agent — Telegram adapter |
| `lyra_discord` | `python -m lyra --adapter discord` | Lyra AI agent — Discord adapter |
| `voicecli_tts` | `voicecli serve --engine qwen-fast` | TTS daemon — keeps Qwen model warm in VRAM for zero-latency speech generation |
| `voicecli_stt` | `voicecli stt-serve` | STT daemon — keeps faster-whisper loaded for fast dictation via `voicecli dictate` |
| `forge` | `forge/scripts/run.sh` | Forge gallery — serves `~/.roxabi/forge/` with live-reload on `localhost:8080` |

## Layout

```
~/projects/lyra-stack/
  supervisord.conf      — daemon config (socket, logs, includes conf.d)
  conf.d/               — symlinks only, each project owns its conf
    lyra_telegram.conf  → ~/projects/lyra/supervisor/conf.d/lyra_telegram.conf
    lyra_discord.conf   → ~/projects/lyra/supervisor/conf.d/lyra_discord.conf
    voicecli_tts.conf   → ~/projects/voiceCLI/supervisor/conf.d/voicecli_tts.conf
    voicecli_stt.conf   → ~/projects/voiceCLI/supervisor/conf.d/voicecli_stt.conf
    forge.conf          → ~/projects/lyra-stack/forge/conf.d/forge.conf
  forge/                — forge tooling (serve.py, gen-manifest.py, index.html, build.sh)
    serve.py            — HTTP server + SSE live-reload + manifest generation (uses FORGE_DIR env var)
    gen-manifest.py     — standalone manifest generator
    index.html          — gallery UI (served by serve.py, copied into _dist for Cloudflare)
    build.sh            — assemble _dist/ for static deployment
    seed-meta.py        — one-shot: inject diagram:* meta tags into HTML files
    update-meta.py      — one-shot: audit and correct meta tags
  scripts/
    start.sh            — start supervisord (idempotent, uses full path to $HOME/.local/bin/supervisord)
    supervisorctl.sh    — supervisorctl wrapper (full path to $HOME/.local/bin/supervisorctl)
  logs/                 — supervisord own logs only
  Makefile              — control interface (see below)
```

## Commands

```bash
cd ~/projects/lyra-stack

make start           # start supervisord + all services (idempotent)
make ps              # status of all services

make lyra            # status lyra_telegram + lyra_discord
make lyra start|reload|stop|logs|errlogs

make telegram        # lyra_telegram only
make telegram start|reload|stop|logs|errlogs

make discord         # lyra_discord only
make discord start|reload|stop|logs|errlogs

make tts             # show tts status
make tts start|reload|stop|logs|errlogs

make stt             # show stt status
make stt start|reload|stop|logs|errlogs

make forge             # show forge status
make forge start|reload|stop|logs|errlogs
make forge push        # push ~/.roxabi/forge/ → Google Drive
make forge pull        # pull Google Drive → ~/.roxabi/forge/
make forge sync        # push then pull (bidirectional)
make forge build       # regenerate manifest + assemble _dist/
make forge deploy      # build + deploy to Cloudflare Pages → diagrams.roxabi.com
make forge deploy-prod # rsync ~/.roxabi/forge/ → production (with --delete)
make forge du          # disk usage per project in ~/.roxabi/forge/
make deploy            # full lyra stack deploy (git pull + rsync all)

# Deploy notes:
# - `make forge deploy` déploie sur la branche `main` (--branch=main) → diagrams.roxabi.com
# - CLOUDFLARE_API_TOKEN lu depuis .env automatiquement (ne pas exporter manuellement)
# - Le repo lyra-stack est sur la branche `staging` — sans --branch=main, wrangler déploie en preview uniquement

# systemd
systemctl --user status lyra-stack   # unit status
systemctl --user restart lyra-stack  # restart all
```

## Forge Architecture

Code and data are strictly separated:
- **Code** (`lyra-stack/forge/`) — all tooling, version-controlled in git
- **Data** (`~/.roxabi/forge/`) — diagram/gallery HTML files only, synced via rclone/rsync

Scripts use `FORGE_DIR` env var (defaults to `~/.roxabi/forge/`) to locate data.
`DIAGRAMS_DIR` is still accepted as a fallback for backward compatibility.
`run.sh` sets this and runs `serve.py` from the canonical forge location (with local fallback).
`index.html` is served from the canonical `$FORGE_DIR/index.html`.

```
~/.roxabi/forge/                          ← data only, no tooling
  lyra/                            ← lyra visuals + brand
  roxabi-plugins/                  ← roxabi-plugins brand
  _shared/                         ← cross-project diagrams
  manifest.json                    ← generated, not synced
  _dist/                           ← build output for Cloudflare, not synced
```

## Adding a New Service

1. Add `supervisor/conf.d/<program>.conf` to the project repo (logs → `~/.local/state/<app>/logs/`)
2. Add `supervisor/scripts/supervisorctl.sh` pointing to `$HOME/lyra-stack/supervisord.conf`
3. Logs go to `~/.local/state/<app>/logs/` (created by `make register`)
4. Add `make register` and service targets to the project Makefile
5. Run `make register` — creates the symlink and signals supervisord

See `~/projects/lyra-stack/docs/supervisor-pattern.md` for the full pattern.

## Sockets

| Daemon | Socket |
|--------|--------|
| TTS | `~/.local/share/voicecli/daemon.sock` |
| STT | `~/.local/share/voicecli/stt-daemon.sock` |

## TL;DR

- **Before work:** Use `/dev #N` as the single entry point
- **Decisions:** → see global patterns (@.claude/dev-core.md)
- **Never** commit without asking, push without request, or use `--force`/`--hard`/`--amend`

## Deploy — Cloudflare Pages

La forge gallery (`~/.roxabi/forge/`) est hébergée sur **Cloudflare Pages** (projet `diagrams`).

```bash
make forge deploy   # build + deploy → Cloudflare Pages
```

Requiert la variable d'environnement `CLOUDFLARE_API_TOKEN` (wrangler refuse en mode non-interactif sans elle).

> **Ne pas confondre avec `make deploy`** qui fait un rsync SSH vers `192.168.1.16` (machine locale) — sans rapport avec Cloudflare.

## Gotchas

<!-- Add project-specific gotchas here -->
