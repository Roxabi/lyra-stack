@.claude/stack.yml
@CLAUDE.local.md

# ~/projects/lyra-stack — Lyra Infrastructure

Central supervisord instance for the local machine.
Manages all background services that support Lyra and its ecosystem.

## Services

| Program | Command | Purpose |
|---------|---------|---------|
| `lyra` | `python -m lyra` | Lyra AI agent (Telegram + Discord) |
| `voicecli_tts` | `voicecli serve --engine qwen-fast` | TTS daemon — keeps Qwen model warm in VRAM for zero-latency speech generation |
| `voicecli_stt` | `voicecli stt-serve` | STT daemon — keeps faster-whisper loaded for fast dictation via `voicecli dictate` |

## Layout

```
~/projects/lyra-stack/
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
cd ~/projects/lyra-stack

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

## Critical Rules

## TL;DR

- **Project:** lyra-stack
- **Before work:** Use `/dev #N` as the single entry point — it determines tier (S / F-lite / F-full) and drives the full lifecycle
- **All code changes** → worktree: `git worktree add ../lyra-stack-XXX -b feat/XXX-slug staging`
- **Always** `AskUserQuestion` for choices — never plain-text questions
- **Never** commit without asking, push without request, or use `--force`/`--hard`/`--amend`
- **Always** use appropriate skill even without slash command
- **Before code:** Read relevant standards doc (see Coding Standards section below)
- **Orchestrator** delegates to agents — only minor fixes directly

### 1. Dev Process

**Entry point: `/dev #N`** — single command that scans artifacts, shows progress, and delegates to the right phase skill.

| Tier | Criteria | Phases |
|------|----------|--------|
| **S** | ≤3 files, no arch, no risk | triage → implement → pr → validate → review → fix* → cleanup* |
| **F-lite** | Clear scope, single domain | Frame → spec → plan → implement → verify → ship |
| **F-full** | New arch, unclear reqs, >2 domains | Frame → analyze → spec → plan → implement → verify → ship |

`*` = conditional (runs only if applicable)

Phases: **Frame** (problem) → **Shape** (spec) → **Build** (code) → **Verify** (review) → **Ship** (release).

### 2. AskUserQuestion

Always `AskUserQuestion` for: decisions, choices (≥2 options), approach proposals.
**Never** plain-text "Do you want..." / "Should I..." → use the tool.

### 3. Orchestrator Delegation

Orchestrator does not modify code/docs directly. Delegate: FE→`frontend-dev` | BE→`backend-dev` | Infra→`devops` | Docs→`doc-writer` | Tests→`tester` | Fixes→`fixer`. Exception: typo/single-line. Deploy→`devops` only.

### 4. Parallel Execution

≥3 complex tasks → AskUserQuestion: Sequential | Parallel (Recommended).
F-full + ≥4 independent tasks in 1 domain → multiple same-type agents on separate file groups.

### 5. Git

Format: `<type>(<scope>): <desc>` + `Co-Authored-By: Claude <model> <noreply@anthropic.com>`
Types: feat|fix|refactor|docs|style|test|chore|ci|perf
Never push without request. Never force/hard/amend. Hook fail → fix + NEW commit.

### 6. Artifact Model

Artifacts are the state markers `/dev` uses for progress detection and resumption.

| Type | Directory | Question answered |
|------|-----------|-------------------|
| **Frame** | `artifacts/frames/` | What's the problem? |
| **Analysis** | `artifacts/analyses/` | How deep is it? |
| **Spec** | `artifacts/specs/` | What will we build? |
| **Plan** | `artifacts/plans/` | How do we build it? |

### 7. Mandatory Worktree

```bash
git worktree add ../lyra-stack-XXX -b feat/XXX-slug staging
cd ../lyra-stack-XXX && uv sync
```

Exceptions: XS (confirm via AskUserQuestion) | `/dev` pre-implementation artifacts (frame, analysis, spec, plan) | `/promote` release artifacts.
**Never code on main/staging without worktree.**

### 8. Code Review

MUST read [code-review](docs/standards/code-review.md). Conventional Comments. Block only: security, correctness, standard violations.

### 9. Coding Standards

| Context | Read |
|---------|------|
| Tests | [testing](docs/standards/testing.md) |
| Infrastructure / DevOps | [backend-patterns](docs/standards/backend-patterns.md) |

## Skills & Agents

Skills: always use appropriate skill. Workflow skills → `dev-core` plugin.
Agents: Sonnet = all agents (frontend-dev, backend-dev, devops, doc-writer, fixer, tester, architect, product-lead, security-auditor).

**Shared agent rules:** Never commit/push (lead handles git) | Never force/hard/amend | Stage specific files only | Escalate blockers → lead | Message lead on completion.

## Gotchas

<!-- Add project-specific gotchas here -->
