#!/usr/bin/env python3
"""Rename xcresult attachment exports to their XCTAttachment names.

`xcrun xcresulttool export attachments` writes each file under a UUID and records
the attachment's real name in manifest.json as
`<attachment name>_<index>_<UUID>.png`. This copies each export to
`<output dir>/<attachment name>.png` so the screenshots land in the repo under the
readable names the UI tests set.

Usage: export_screenshots.py <export dir> <output dir>
"""

import json
import re
import shutil
import sys
from pathlib import Path

SUFFIX = re.compile(r"_\d+_[0-9A-Fa-f-]{36}(?=\.[^.]+$)")


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2

    export_dir = Path(sys.argv[1])
    out_dir = Path(sys.argv[2])
    manifest_path = export_dir / "manifest.json"

    if not manifest_path.exists():
        print(f"error: no manifest at {manifest_path}", file=sys.stderr)
        return 1

    out_dir.mkdir(parents=True, exist_ok=True)
    manifest = json.loads(manifest_path.read_text())

    written = 0
    for test in manifest:
        for attachment in test.get("attachments", []):
            source = export_dir / attachment["exportedFileName"]
            name = SUFFIX.sub("", attachment["suggestedHumanReadableName"])
            if not source.exists():
                print(f"warning: missing {source}", file=sys.stderr)
                continue
            shutil.copyfile(source, out_dir / name)
            print(f"{test['testIdentifier']} -> {out_dir / name}")
            written += 1

    if written == 0:
        print("error: no attachments exported", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
