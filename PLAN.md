# lyra-stack — Plan

## 1. Secret management contract
Each module's supervisor conf must not embed secrets directly.
Add a `scripts/run.sh` wrapper per module that sources `.env` before launching,
so `command=` in the `.conf` points to the wrapper, not the binary.
Affects: lyra, voiceCLI.

## 2. CLAUDE.md machine-local override
The committed `CLAUDE.md` in lyra-stack exposes hostname, GPU, internal IP.
Move machine-specific content to a gitignored `CLAUDE.local.md` that Claude Code
merges at runtime. The committed file stays generic.

## 3. make setup — pin modules to tags
`stack.toml` currently clones at HEAD.
Add a `tag` field per module and have `setup.py` checkout that tag after cloning.
Ensures reproducible setups and protects against supply chain drift.

## 4. imageCLI register no-op
imageCLI has no daemon so `make register` should skip supervisord registration
gracefully. Verify `make setup --all` doesn't break on it.

## 5. supervisor-pattern.md refresh
Do a full pass now that the pattern is stable:
- Update all path references
- Document the LYRA_STACK_DIR convention
- Remove stale sections

## 6. Lyra #79 — Voice TTS in Telegram
Implement voice reply support in Lyra's Telegram channel.
Uses voicecli_tts daemon (already running).
Tracked in: https://github.com/Roxabi/lyra/issues/79

## 7. Lyra #83 — Memory layer
L0 compaction, identity anchor, session lifecycle for the Lyra agent.
Tracked in: https://github.com/Roxabi/lyra/issues/83
