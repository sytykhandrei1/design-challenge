#!/usr/bin/env python3
"""Verify byte identity of the renderer, build configuration and shipped assets.

Run from any directory; no third-party dependencies or asset generation.
The original baseline was captured before the September 2026 authoring-only cleanup.
Intentional subsequent changes are recorded in Docs/digital-illustrated-backs.md.
"""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "Docs/runtime-baseline-sha256.json").read_text())
failures = []
for name, expected in manifest.items():
    path = root / name
    if not path.is_file():
        failures.append(f"Missing: {name}")
    elif hashlib.sha256(path.read_bytes()).hexdigest() != expected["sha256"]:
        failures.append(f"Changed: {name}")
if failures:
    raise SystemExit("\n".join(failures))
print(f"PASS: {len(manifest)} files match the documented SHA-256 baseline")
