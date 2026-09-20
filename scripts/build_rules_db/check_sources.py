#!/usr/bin/env python3
"""Verify the pinned DSA source data hasn't drifted.

Compares the SHA-256 of each `*.yaml` file under `<source>/de-DE` against the
hashes pinned in `specs/rules/SOURCES.yaml`. Exits non-zero on any mismatch or
missing file, printing which file and which hash differed.
"""

import argparse
import hashlib
import sys
from pathlib import Path

import yaml


def parse_args():
    p = argparse.ArgumentParser(description="Verify pinned DSA source data checksums")
    p.add_argument("--source", required=True, type=Path,
                    help="Path to dsa_companion_data/Data/ directory")
    p.add_argument("--pins", required=True, type=Path,
                    help="Path to specs/rules/SOURCES.yaml")
    return p.parse_args()


def main(source: Path, pins: Path) -> int:
    if not pins.is_file():
        print(f"Pins file not found: {pins}", file=sys.stderr)
        return 1

    with open(pins, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f) or {}
    pinned = (doc.get("optolith") or {}).get("files") or {}

    de_de = source / "de-DE"
    if not de_de.is_dir():
        print(f"Source de-DE directory not found: {de_de}", file=sys.stderr)
        return 1

    errors = []

    for name, pinned_hash in sorted(pinned.items()):
        path = de_de / name
        if not path.is_file():
            errors.append(f"missing file: {path}")
            continue
        actual_hash = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual_hash != pinned_hash:
            errors.append(
                f"checksum mismatch: {path}\n"
                f"  expected {pinned_hash}\n"
                f"  actual   {actual_hash}"
            )

    if errors:
        print("Rules source data does not match specs/rules/SOURCES.yaml:", file=sys.stderr)
        for err in errors:
            print(f"  - {err}", file=sys.stderr)
        return 1

    print(f"Verified {len(pinned)} source files against {pins}")
    return 0


if __name__ == "__main__":
    args = parse_args()
    sys.exit(main(args.source, args.pins))
