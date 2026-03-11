#!/usr/bin/env python3
"""lyra-stack setup — clone and register modules, start supervisord."""

import os
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
        return False
    return True


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
    cloned = []

    for name, module in modules.items():
        optional = module.get("optional", False)
        if optional and not include_optional:
            print(f"  skip  {name}  (optional — use --all to include)")
            continue

        path = Path(module["path"]).expanduser()

        if path.exists():
            print(f"  ✓  {name}  (already at {path})")
        else:
            if not ask(f"  Clone {name} → {path}?"):
                print(f"  skip  {name}")
                continue
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

        cloned.append(name)
        print()

    print("Starting supervisord...")
    run(str(LYRA_STACK_DIR / "scripts" / "start.sh"))

    print()
    print("─" * 40)
    print("Done.")
    print()
    print("  make ps              status of all services")
    print("  make lyra reload     restart lyra")
    print("  make tts reload      restart voicecli_tts")
    print("  make stt reload      restart voicecli_stt")
    print()
    if include_optional is False and any(m.get("optional") for m in modules.values()):
        print(
            "  make setup ARGS=--all    include optional modules (imageCLI, roxabi-vault)"
        )
        print()


if __name__ == "__main__":
    main()
