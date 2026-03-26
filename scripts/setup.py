#!/usr/bin/env python3
"""lyra-stack setup — clone and register modules, scaffold config, start supervisord."""

import os
import shutil
import subprocess
import sys
import tomllib
from pathlib import Path

STACK_FILE = Path(__file__).parent.parent / "stack.toml"
LYRA_STACK_DIR = Path(
    os.environ.get("LYRA_STACK_DIR", Path.home() / "projects" / "lyra-stack")
)


def run(cmd: str, cwd: Path | None = None, check: bool = True) -> int:
    sys.stdout.flush()
    result = subprocess.run(cmd, shell=True, cwd=cwd)
    if check and result.returncode != 0:
        print(f"  ✗  Command failed: {cmd}")
        sys.exit(result.returncode)
    return result.returncode


def ask(prompt: str, default: bool = True) -> bool:
    hint = "Y/n" if default else "y/N"
    try:
        resp = input(f"{prompt} [{hint}] ").strip().lower()
    except (EOFError, KeyboardInterrupt):
        print()
        sys.exit(0)
    if not resp:
        return default
    return resp in ("y", "yes")


def check_prereqs() -> bool:
    checks = {
        "git": ("git --version", None),
        "uv": (
            "uv --version",
            "https://docs.astral.sh/uv/getting-started/installation/",
        ),
        "supervisord": (
            "supervisord --version",
            "Run: uv tool install supervisor",
        ),
        "claude": (
            "claude --version",
            "Run: npm install -g @anthropic-ai/claude-code",
        ),
        "ssh": ("ssh -T git@github.com", None),  # exits 1 on success for GitHub
    }
    print("Checking prerequisites...")
    failed = []
    for name, (cmd, install_url) in checks.items():
        result = subprocess.run(cmd, shell=True, capture_output=True)
        ok = result.returncode in (0, 1) if name == "ssh" else result.returncode == 0
        print(
            f"  {'✓' if ok else '✗'}  {name}"
            + (f"  →  {install_url}" if not ok and install_url else "")
        )
        if not ok:
            failed.append(name)
    if failed:
        print("\nFix the above before running setup.")
        print("Tip: run scripts/provision.sh to install all prerequisites.")
        return False
    return True


# ── Config scaffolding ───────────────────────────────────────────────────────


def scaffold_env(lyra_dir: Path) -> None:
    """Copy .env.example → .env if missing."""
    env_file = lyra_dir / ".env"
    example = lyra_dir / ".env.example"
    if env_file.exists():
        print("  ✓  .env already exists")
        return
    if not example.exists():
        print("  ✗  .env.example not found — skipping")
        return
    shutil.copy(example, env_file)
    print("  ✓  .env created from .env.example")
    print("       → Edit ~/projects/lyra/.env and fill in your tokens")


def scaffold_config_toml(lyra_dir: Path) -> None:
    """Copy config.toml.example → config.toml if missing."""
    config_file = lyra_dir / "config.toml"
    example = lyra_dir / "config.toml.example"
    if config_file.exists():
        print("  ✓  config.toml already exists")
        return
    if not example.exists():
        print("  ✗  config.toml.example not found — skipping")
        return
    shutil.copy(example, config_file)
    print("  ✓  config.toml created from config.toml.example")
    print("       → Edit ~/projects/lyra/config.toml and fill in your user IDs")


def bootstrap_diagrams() -> None:
    """Create ~/.agent/diagrams/ and copy server files from lyra-stack."""
    diagrams_dir = Path.home() / ".agent" / "diagrams"
    diagrams_src = LYRA_STACK_DIR / "diagrams"
    diagrams_dir.mkdir(parents=True, exist_ok=True)

    for name in ("serve.py", "gen-manifest.py", "index.html"):
        src = diagrams_src / name
        dst = diagrams_dir / name
        if not src.exists():
            continue
        if dst.exists():
            # Update if source is newer
            if src.stat().st_mtime <= dst.stat().st_mtime:
                continue
        shutil.copy2(src, dst)

    # Register diagrams conf symlink
    conf_src = diagrams_src / "conf.d" / "diagrams.conf"
    conf_dst = LYRA_STACK_DIR / "conf.d" / "diagrams.conf"
    if conf_src.exists() and not conf_dst.exists():
        conf_dst.parent.mkdir(parents=True, exist_ok=True)
        conf_dst.symlink_to(conf_src)

    print("  ✓  Diagrams gallery bootstrapped (~/.agent/diagrams/)")


def symlink_voicecli(voicecli_dir: Path) -> None:
    """Symlink voicecli venv binary to ~/.local/bin/."""
    venv_bin = voicecli_dir / ".venv" / "bin" / "voicecli"
    local_bin = Path.home() / ".local" / "bin" / "voicecli"
    if local_bin.exists() or local_bin.is_symlink():
        print("  ✓  voicecli already on PATH")
        return
    if not venv_bin.exists():
        print("  ✗  voicecli venv binary not found — skipping symlink")
        return
    local_bin.parent.mkdir(parents=True, exist_ok=True)
    local_bin.symlink_to(venv_bin)
    print(f"  ✓  voicecli symlinked → {local_bin}")


def init_agents(lyra_dir: Path) -> None:
    """Run lyra agent init to seed the DB from TOML files."""
    agent_init = lyra_dir / ".venv" / "bin" / "lyra"
    if not agent_init.exists():
        print("  ✗  lyra CLI not found in venv — skipping agent init")
        return
    result = subprocess.run(
        f"{agent_init} agent init",
        shell=True,
        cwd=lyra_dir,
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        print("  ✓  lyra agent init — agents seeded into DB")
    else:
        # Non-fatal — may fail if DB already has agents
        print(f"  !  lyra agent init skipped ({result.stderr.strip() or 'already initialized'})")


def create_log_dirs() -> None:
    """Create XDG-compliant log directories."""
    state = Path.home() / ".local" / "state"
    for app in ("lyra", "voicecli", "lyra-stack"):
        log_dir = state / app / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
    print("  ✓  Log directories created (~/.local/state/*/logs/)")


# ── Main ─────────────────────────────────────────────────────────────────────


def main() -> None:
    include_optional = "--all" in sys.argv

    with open(STACK_FILE, "rb") as f:
        config = tomllib.load(f)

    modules = config.get("modules", {})

    print("\nlyra-stack setup")
    print("─" * 40)
    print()

    if not check_prereqs():
        sys.exit(1)

    print()

    # ── Phase 1: Clone + install + register ──────────────────────────────────

    lyra_dir = None
    voicecli_dir = None

    installed_optional: set[str] = set()

    for name, module in modules.items():
        optional = module.get("optional", False)
        path = Path(module["path"]).expanduser()

        if name == "lyra":
            lyra_dir = path
        elif name == "voiceCLI":
            voicecli_dir = path

        # Optional modules: ask unless --all was passed
        if optional and not include_optional:
            if path.exists():
                print(f"  ✓  {name}  (already at {path})")
            elif not ask(f"  Install {name}? (optional)", default=False):
                print(f"  skip  {name}")
                continue
        elif not optional:
            pass  # required — always install

        if path.exists():
            if name not in ("lyra",):  # lyra already printed above if optional check passed
                print(f"  ✓  {name}  (already at {path})")
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            run(f"git clone {module['repo']} {path}")
            tag = module.get("tag", "").strip()
            if tag:
                print(f"       pinning to {tag}...")
                run(f"git checkout {tag}", cwd=path)

        print("       installing...")
        run(module.get("install", "uv sync"), cwd=path)

        if module.get("register", True):
            print("       registering...")
            env = {**os.environ, "LYRA_STACK_DIR": str(LYRA_STACK_DIR)}
            subprocess.run("make register", shell=True, cwd=path, env=env, check=True)
        else:
            print("       skipping registration (no daemon)")

        if optional:
            installed_optional.add(name)
        print()

    # If voiceCLI was installed, re-sync lyra with the voice extra
    if "voiceCLI" in installed_optional and lyra_dir and lyra_dir.exists():
        print("       re-syncing lyra with voice support...")
        run("uv sync --extra voice", cwd=lyra_dir)
        print()

    # ── Phase 2: Post-setup scaffolding ──────────────────────────────────────

    print("Post-setup")
    print("─" * 40)
    print()

    create_log_dirs()

    if ask("  Install diagrams gallery? (optional)", default=False):
        bootstrap_diagrams()
    else:
        print("  skip  diagrams")

    if voicecli_dir and voicecli_dir.exists():
        symlink_voicecli(voicecli_dir)

    if lyra_dir and lyra_dir.exists():
        scaffold_env(lyra_dir)
        scaffold_config_toml(lyra_dir)
        init_agents(lyra_dir)

    print()

    # ── Phase 3: Start supervisord ───────────────────────────────────────────

    print("Starting supervisord...")
    run(str(LYRA_STACK_DIR / "scripts" / "start.sh"))

    print()
    print("─" * 40)
    print("Setup complete!")
    print()
    print("  make ps              status of all services")
    print("  make lyra reload     restart lyra")
    print("  make tts reload      restart voicecli_tts")
    print("  make stt reload      restart voicecli_stt")
    print()

    # ── Remaining manual steps ───────────────────────────────────────────────

    manual_steps = []

    if lyra_dir:
        env_file = lyra_dir / ".env"
        config_file = lyra_dir / "config.toml"
        if env_file.exists():
            # Check if tokens are filled in
            content = env_file.read_text()
            if "TELEGRAM_TOKEN=\n" in content or "TELEGRAM_TOKEN=" not in content:
                manual_steps.append(
                    f"Fill in bot tokens:\n"
                    f"     nano {lyra_dir}/.env\n"
                    f"     → TELEGRAM_TOKEN, DISCORD_TOKEN, etc.\n"
                    f"     → Get Telegram token from @BotFather\n"
                    f"     → Get Discord token from discord.com/developers"
                )
        if config_file.exists():
            content = config_file.read_text()
            if "owner_users = []" in content:
                manual_steps.append(
                    f"Fill in your user IDs:\n"
                    f"     nano {lyra_dir}/config.toml\n"
                    f"     → Telegram ID: message @userinfobot\n"
                    f"     → Discord ID: Settings → Advanced → Developer Mode"
                )

    # Check if Claude is authenticated
    result = subprocess.run(
        "claude --version", shell=True, capture_output=True, text=True
    )
    if result.returncode != 0:
        manual_steps.append("Install and authenticate Claude CLI:\n     claude")
    else:
        # Claude is installed but might not be authenticated
        manual_steps.append(
            "Authenticate Claude CLI (if not already done):\n     claude"
        )

    manual_steps.append(
        "Add bot tokens to the credential store:\n"
        "     cd ~/projects/lyra && lyra bot add"
    )

    if manual_steps:
        print("Remaining manual steps:")
        print()
        for i, step in enumerate(manual_steps, 1):
            print(f"  {i}. {step}")
            print()

    if include_optional is False and any(m.get("optional") for m in modules.values()):
        print(
            "  make setup ARGS=--all    include optional modules (imageCLI, roxabi-vault)"
        )
        print()


if __name__ == "__main__":
    main()
