"""hero.py's view of every sample hero (specs/heroes/*.json, less the *.companions.json build
files), one JSON per hero, for the app's HeroSheetMappingTests: the app's Hero -> HeroSheet
mapping must state the same facts.

    python -m rulec.hero_sheet_fixtures <heroes dir> <out dir>    (run from scripts/)
"""
import json
import sys
from pathlib import Path

from rulec.hero import from_optolith


def main(heroes: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    for p in sorted(p for p in heroes.glob("*.json") if not p.name.endswith(".companions.json")):
        data = json.dumps(from_optolith(p), ensure_ascii=False, indent=1, sort_keys=True) + "\n"
        (out / (p.stem + ".json")).write_text(data, encoding="utf-8")
        print(f"wrote {out / (p.stem + '.json')}")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
