@.claude/stack.yml
@CLAUDE.local.md

# ~/projects/lyra-stack — Lyra Infrastructure

Central supervisord instance for the local machine.
Manages all background services that support Lyra and its ecosystem.

## Services

| Program | Command | Purpose |
|---------|---------|---------|
| `lyra_telegram` | `python -m lyra --adapter telegram` | Lyra AI agent — Telegram adapter |
| `lyra_discord` | `python -m lyra --adapter discord` | Lyra AI agent — Discord adapter |
| `voicecli_tts` | `voicecli serve --engine qwen-fast` | TTS daemon — keeps Qwen model warm in VRAM for zero-latency speech generation |
| `voicecli_stt` | `voicecli stt-serve` | STT daemon — keeps faster-whisper loaded for fast dictation via `voicecli dictate` |

## Layout

```
~/projects/lyra-stack/
  supervisord.conf      — daemon config (socket, logs, includes conf.d)
  conf.d/               — symlinks only, each project owns its conf
    lyra_telegram.conf  → ~/projects/lyra/supervisor/conf.d/lyra_telegram.conf
    lyra_discord.conf   → ~/projects/lyra/supervisor/conf.d/lyra_discord.conf
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
```

## Adding a New Service

1. Add `supervisor/conf.d/<program>.conf` to the project repo (logs → project's `supervisor/logs/`)
2. Add `supervisor/scripts/supervisorctl.sh` pointing to `$HOME/lyra-stack/supervisord.conf`
3. Add `supervisor/logs/` to `.gitignore`
4. Add `make register` and service targets to the project Makefile
5. Run `make register` — creates the symlink and signals supervisord

See `~/projects/lyra-stack/docs/supervisor-pattern.md` for the full pattern.

## Sockets

| Daemon | Socket |
|--------|--------|
| TTS | `~/.local/share/voicecli/daemon.sock` |
| STT | `~/.local/share/voicecli/stt-daemon.sock` |

## Critical Rules

## TL;DR

- **Before work:** Use `/dev #N` as the single entry point
- **Always** `AskUserQuestion` for choices — never plain-text questions
- **Never** commit without asking, push without request, or use `--force`/`--hard`/`--amend`

### 1. Dev Process

| Tier | Criteria | Phases |
|------|----------|--------|
| **S** | ≤3 files, no arch, no risk | triage → implement → pr → validate → review → fix* → cleanup* |
| **F-lite** | Clear scope | frame → spec → plan → implement → verify → ship |

### 2. AskUserQuestion

Always `AskUserQuestion` for: decisions, choices (≥2 options), approach proposals.
**Never** plain-text "Do you want..." / "Should I..." → use the tool.

### 3. Parallel Execution

≥3 independent tasks → AskUserQuestion: Sequential | Parallel (Recommended).

### 4. Git

Format: `<type>(<scope>): <desc>` + `Co-Authored-By: Claude <model> <noreply@anthropic.com>`
Types: feat|fix|refactor|docs|style|test|chore|ci|perf
Never push without request. Never force/hard/amend. Hook fail → fix + NEW commit.

### 5. Worktree

```bash
git worktree add ../lyra-stack-XXX -b feat/XXX-slug staging
cd ../lyra-stack-XXX
```

Exception: XS changes (confirm via AskUserQuestion).
**Never code on main/staging without worktree.**

## Gotchas

<!-- Add project-specific gotchas here -->
