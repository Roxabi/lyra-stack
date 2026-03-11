# Contributing to lyra-stack

## Overview

lyra-stack manages all Roxabi background services (Lyra agent, TTS, STT) through a single supervisord instance. See `docs/supervisor-pattern.md` for the full architecture.

## Development Setup

```bash
git clone https://github.com/Roxabi/lyra-stack.git
cd lyra-stack
make start    # start supervisord (idempotent)
make ps       # verify all services
```

## Adding a New Service

1. Add your supervisor config to your project repo under `supervisor/`
2. Symlink it: `ln -s /path/to/project/supervisor/service.conf conf.d/`
3. Run `make start` to register with supervisord

See `docs/supervisor-pattern.md` for the full pattern and contract.

## Branch Naming

- `feat/` — new features or services
- `fix/` — bug fixes
- `chore/` — maintenance, config updates

## Commit Format

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add redis service config
fix: correct log rotation path for voicecli_tts
chore: update supervisor version
```

## Pull Request Process

1. Branch from `main`
2. Make your changes and test locally with supervisord
3. Verify symlinks in `conf.d/` are correct
4. Open a PR with a clear description

## Issues

Use [GitHub Issues](https://github.com/Roxabi/lyra-stack/issues) for bugs and feature requests.
