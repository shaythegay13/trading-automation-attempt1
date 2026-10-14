#!/usr/bin/env python3
"""Check reaction files, live-trading defaults, and repository hygiene.

This does not place orders or talk to Kalshi. It only reads the files in
this checkout.
"""

from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REACTIONS = ROOT / "reactions"
CONFIG = ROOT / "config.json"
ENV_EXAMPLE = ROOT / ".env.example"
GITIGNORE = ROOT / ".gitignore"

ASSIGN_RE = {
    "tradingMode": re.compile(r'^tradingMode\s*:?=\s*"([^"]*)"'),
    "liveArmToken": re.compile(r'^liveArmToken\s*:?=\s*"([^"]*)"'),
    "enableLiveOrders": re.compile(r"^enableLiveOrders\s*:?=\s*(true|false)\b", re.IGNORECASE),
}

TRACKED_FORBIDDEN_SUFFIXES = (
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".traineddata",
    ".pro.user",
    ".log",
)


def load_reactions():
    files = sorted(REACTIONS.glob("*.json"))
    loaded = []
    errors = []
    if not files:
        errors.append("reactions/ has no JSON files")
    for path in files:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"{path.name}: invalid JSON ({exc})")
            continue
        if not isinstance(data, dict):
            errors.append(f"{path.name}: root is not an object")
            continue
        for key in ("areas", "code", "points"):
            if key not in data:
                errors.append(f"{path.name}: missing {key}")
        code = data.get("code", "")
        if not isinstance(code, str):
            errors.append(f"{path.name}: code is not a string")
            code = ""
        loaded.append((path, code))
    return loaded, errors


def first_assignments(code: str) -> dict:
    found = {}
    for line in code.splitlines():
        stripped = line.strip()
        if not stripped or stripped.startswith(";"):
            continue
        for name, pattern in ASSIGN_RE.items():
            if name in found:
                continue
            match = pattern.match(stripped)
            if match:
                found[name] = match.group(1)
    return found


def live_trading_errors(loaded=None):
    if loaded is None:
        loaded, errors = load_reactions()
    else:
        errors = []
    for path, code in loaded:
        assigned = first_assignments(code)
        name = path.name
        if "tradingMode" in assigned and assigned["tradingMode"] != "SIM":
            errors.append(f"{name}: tradingMode defaults to {assigned['tradingMode']!r}")
        if "liveArmToken" in assigned and assigned["liveArmToken"] != "":
            errors.append(f"{name}: liveArmToken is not empty")
        if "enableLiveOrders" in assigned and assigned["enableLiveOrders"].lower() != "false":
            errors.append(f"{name}: enableLiveOrders defaults to {assigned['enableLiveOrders']}")
        if name.startswith("Kalshi-LiveTrading-"):
            for key in ("tradingMode", "liveArmToken", "enableLiveOrders"):
                if key not in assigned:
                    errors.append(f"{name}: missing default assignment for {key}")
        if name == "Kalshi-Maker-SIM.json" and assigned.get("tradingMode") != "SIM":
            errors.append(f"{name}: maker agent is not SIM")
        if name == "Kalshi-PaperTrading.json" and assigned.get("enableLiveOrders", "").lower() != "false":
            errors.append(f"{name}: paper agent does not default enableLiveOrders to false")
    return errors


def config_errors():
    errors = []
    try:
        config = json.loads(CONFIG.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        return [f"config.json: {exc}"]
    reaction = str(config.get("reaction_file", "")).replace("\\", "/")
    if not reaction:
        return ["config.json: reaction_file is empty"]
    path = ROOT / reaction
    if not path.is_file():
        errors.append(f"config.json: reaction_file {reaction} does not exist")
        return errors
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        code = data.get("code", "") if isinstance(data, dict) else ""
    except json.JSONDecodeError as exc:
        return [f"config.json reaction: invalid JSON ({exc})"]
    assigned = first_assignments(code if isinstance(code, str) else "")
    if assigned.get("tradingMode") not in (None, "SIM"):
        errors.append("config.json selects a reaction whose tradingMode is not SIM")
    if assigned.get("enableLiveOrders", "false").lower() != "false":
        errors.append("config.json selects a reaction with live orders enabled")
    return errors


def env_example_errors():
    errors = []
    if not ENV_EXAMPLE.is_file():
        return [".env.example is missing"]
    names = []
    for lineno, raw in enumerate(ENV_EXAMPLE.read_text(encoding="utf-8").splitlines(), 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if "=" not in line:
            errors.append(f".env.example:{lineno}: expected NAME=")
            continue
        name, value = line.split("=", 1)
        if not re.fullmatch(r"[A-Z][A-Z0-9_]*", name):
            errors.append(f".env.example:{lineno}: invalid name")
        if value != "":
            errors.append(f".env.example:{lineno}: value is not empty")
        names.append(name)
    required = {"KALSHI_API_KEY_ID", "KALSHI_PRIVATE_KEY", "KALSHI_KEY_PASSPHRASE"}
    missing = sorted(required - set(names))
    if missing:
        errors.append(".env.example missing " + ", ".join(missing))
    if (ROOT / ".env").exists():
        errors.append(".env exists in the working tree; do not commit it")
    return errors


def gitignore_errors():
    errors = []
    if not GITIGNORE.is_file():
        return [".gitignore is missing"]
    text = GITIGNORE.read_text(encoding="utf-8")
    for rule in (".env", "*.exe", "*.dll", "*.traineddata", "reactions/apikey.json", "reactions/privatekey.json"):
        if rule not in text.splitlines():
            errors.append(f".gitignore missing rule {rule}")
    return errors


def index_errors():
    errors = []
    try:
        listed = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT)
    except (OSError, subprocess.CalledProcessError) as exc:
        return [f"git ls-files failed: {exc}"]
    for path in listed.decode().split("\0"):
        if not path:
            continue
        lower = path.lower()
        if lower == ".env" or (lower.startswith(".env.") and lower != ".env.example"):
            errors.append(f"tracked env file: {path}")
        if lower.endswith(TRACKED_FORBIDDEN_SUFFIXES):
            errors.append(f"tracked binary or artifact: {path}")
    return errors


def collect_errors():
    loaded, errors = load_reactions()
    errors.extend(live_trading_errors(loaded))
    errors.extend(config_errors())
    errors.extend(env_example_errors())
    errors.extend(gitignore_errors())
    errors.extend(index_errors())
    return errors


def main() -> int:
    errors = collect_errors()
    if errors:
        print("repository check failed:")
        for error in errors:
            print(f"  - {error}")
        return 1
    print("repository check passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
