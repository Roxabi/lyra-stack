# lyra-stack — Plan

## ✅ 1. Secret management contract
Each module's supervisor conf must not embed secrets directly.
Add a `scripts/run.sh` wrapper per module that sources `.env` before launching,
so `command=` in the `.conf` points to the wrapper, not the binary.
Affects: lyra, voiceCLI.

**Done:** `run.sh` (lyra), `run_tts.sh` / `run_stt.sh` (voiceCLI) created and marked executable.
All three `.conf` files updated to point to their wrapper.
**Pending:** reload daemons + commit in lyra and voiceCLI repos.

## ✅ 2. CLAUDE.md machine-local override
The committed `CLAUDE.md` in lyra-stack exposes hostname, GPU, internal IP.
Move machine-specific content to a gitignored `CLAUDE.local.md` that Claude Code
merges at runtime. The committed file stays generic.

**Done:** `CLAUDE.local.md` created (gitignored), `CLAUDE.md` stripped of machine details,
`@CLAUDE.local.md` include added at top, `.gitignore` updated.
**Pending:** commit in lyra-stack repo.

## ✅ 3. make setup — pin modules to tags
`stack.toml` currently clones at HEAD.
Add a `tag` field per module and have `setup.py` checkout that tag after cloning.
Ensures reproducible setups and protects against supply chain drift.

**Done:** `tag = ""` added to all modules in `stack.toml`. `setup.py` updated to
`git checkout <tag>` after clone when non-empty.
**Pending:** commit in lyra-stack repo. Set actual tags once releases are cut.

## ✅ 4. imageCLI register no-op
imageCLI has no daemon so `make register` should skip supervisord registration
gracefully. Verify `make setup --all` doesn't break on it.

**Done:** `register = false` added to imageCLI in `stack.toml`. `setup.py` skips
`make register` when `register = false`.
**Pending:** commit in lyra-stack repo.

## ✅ 5. supervisor-pattern.md refresh
Do a full pass now that the pattern is stable:
- Update all path references
- Document the LYRA_STACK_DIR convention
- Remove stale sections

**Done:** Full rewrite. Added LYRA_STACK_DIR section, updated supervisorctl.sh template,
added run.sh contract, updated make register template, aligned registry table.
**Pending:** `supervisor-pattern.md` lives in `~/projects/` (not a git repo) — no commit needed.

## 6. Lyra #79 — Voice TTS in Telegram
Implement voice reply support in Lyra's Telegram channel.
Uses voicecli_tts daemon (already running).
Tracked in: https://github.com/Roxabi/lyra/issues/79

## 7. Lyra #83 — Memory layer
L0 compaction, identity anchor, session lifecycle for the Lyra agent.
Tracked in: https://github.com/Roxabi/lyra/issues/83

## 8. Lyra — Multi-bot registry upgrade
The adapter registry is currently single-keyed per platform (`dict[str, ChannelAdapter]`)
and `.env` holds one token per platform. The binding key already includes `bot_id`
(`(platform, bot_id, scope_id)` → `(agent, pool_id)`) — the dispatch side needs to catch up.

Changes required:
- Adapter registry key: `str` → `(platform, bot_id)`
- `dispatch_response`: route by `(msg.platform, msg.bot_id)` instead of `msg.channel`
- `TelegramAdapter`: manage one aiogram `Bot` per token
- Config: replace single `TELEGRAM_TOKEN=` with structured config (e.g. `bots.toml`) or
  numbered env vars (`TELEGRAM_TOKEN_1`, `TELEGRAM_TOKEN_2`)

Not a blocker for #79 or #83. Implement after both are merged.
Tracked in: https://github.com/Roxabi/lyra/issues/136
