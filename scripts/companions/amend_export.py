#!/usr/bin/env python3
"""Check a companion build against its Optolith export and inject it.

    amend_export.py <export.json> [--companions X.yaml] [--out Y.json] [--check] [--fix]

Reads <export>.companions.yaml by default. Writes the `hesindion` block
(docs/plans/2026-09-24-companion-data-design.md §4) only when every check
passes; --fix first sets the export's own pet fields from the build.
"""
import argparse
import json
import os
import re
import sys

import yaml

from companions import BuildError, normalise

EXPORT_ATTRIBUTES = {"mu": "cou", "kl": "sgc", "in": "int", "ch": "cha",
                     "ff": "dex", "ge": "agi", "ko": "con", "kk": "str"}
VALUE_LISTS = ("attacks", "advantages", "abilities", "training", "tricks")
TP = re.compile(r"\d+W\d+(?:[+-]\d+)?")
RW = ("kurz", "mittel", "lang")
# The app's parsePetAttacks regex, verbatim.
ATTACK_LINE = re.compile(
    r"([A-ZÄÖÜa-zäöüß]+):\s*AT\s+(\d+)\s+TP\s+(\d+W\d+(?:[+-]\d+)?)\s+RW\s+(kurz|mittel|lang)")


def canonical_attack(attack):
    return f"{attack['name']}: AT {attack['at']} TP {attack['tp']} RW {attack['rw']}"


def parse_talents(text):
    """'Kraftakt 8, Klettern (…)' -> [(part, name or None, value or None)]."""
    parts = []
    for part in text.split(","):
        m = re.fullmatch(r"\s*(.+?)\s+(\d+)\s*", part)
        parts.append((part.strip(), m.group(1), int(m.group(2))) if m else (part.strip(), None, None))
    return parts


def main_attack(pet, values):
    return next((a for a in values["attacks"] if a["name"] == pet.get("attack")), None)


def expected_fields(values, ap_total):
    """Export field -> expected string, for the fields present in the build."""
    fields = {EXPORT_ATTRIBUTES[k]: str(v) for k, v in values.get("attributes", {}).items()}
    for export_key, value_key in (("lp", "lep"), ("ini", "ini"), ("mov", "gs"), ("pa", "vw"), ("pro", "rs")):
        if values.get(value_key) is not None:
            fields[export_key] = str(values[value_key])
    fields["totalAp"] = fields["spentAp"] = str(ap_total)
    return fields


def check_attacks(name, values):
    errors = []
    for attack in values["attacks"]:
        label = f"{name}: attack {attack.get('name')}"
        if not isinstance(attack.get("at"), int):
            errors.append(f"{label}: at must be an integer")
        if not TP.fullmatch(str(attack.get("tp", ""))):
            errors.append(f"{label}: tp {attack.get('tp')!r} is not like 1W6+3")
        if attack.get("rw") not in RW:
            errors.append(f"{label}: rw {attack.get('rw')!r} is not one of kurz, mittel, lang")
    return errors


def check_export(name, pet, values, ap_total):
    errors = []
    for key, expected in expected_fields(values, ap_total).items():
        if key in ("pa", "pro", "totalAp", "spentAp") and key not in pet:
            continue
        if str(pet.get(key)) != expected:
            errors.append(f"{name}: {key} is {pet.get(key)}, build says {expected}")
    attack = main_attack(pet, values)
    if attack is None:
        errors.append(f"{name}: attack {pet.get('attack')!r} is not in values.attacks")
    else:
        if str(pet.get("at")) != str(attack["at"]):
            errors.append(f"{name}: at is {pet.get('at')}, build says {attack['at']}")
        if pet.get("dp") != attack["tp"]:
            errors.append(f"{name}: dp is {pet.get('dp')}, build says {attack['tp']}")
    talents = values.get("talents", {})
    seen = set()
    for _, talent, value in parse_talents(pet.get("talents", "")):
        if talent is None:
            continue
        seen.add(talent)
        if talent not in talents:
            errors.append(f"{name}: talent {talent} {value} is not in values.talents")
        elif talents[talent] != value:
            errors.append(f"{name}: talent {talent} is {value}, build says {talents[talent]}")
    for talent in sorted(set(talents) - seen):
        errors.append(f"{name}: talent {talent} is missing from the export")
    found = {m.group(1): m for m in ATTACK_LINE.finditer(pet.get("notes", ""))}
    for attack in values["attacks"]:
        m = found.get(attack["name"])
        if m is None:
            errors.append(f"{name}: notes: attack {attack['name']} unreadable, "
                          f"expected '{canonical_attack(attack)}'")
        elif (int(m.group(2)), m.group(3), m.group(4)) != (attack["at"], attack["tp"], attack["rw"]):
            errors.append(f"{name}: notes: '{m.group(0)}', build says '{canonical_attack(attack)}'")
    return errors


def fix_export(pet, values, ap_total):
    for key, expected in expected_fields(values, ap_total).items():
        pet[key] = expected
    attack = main_attack(pet, values)
    if attack is not None:
        pet["at"], pet["dp"] = str(attack["at"]), attack["tp"]
    talents = values.get("talents", {})
    parts, seen = [], set()
    for part, talent, _ in parse_talents(pet.get("talents", "")):
        if talent in talents:
            seen.add(talent)
            parts.append(f"{talent} {talents[talent]}")
        elif part:
            parts.append(part)
    parts += [f"{t} {v}" for t, v in talents.items() if t not in seen]
    pet["talents"] = ", ".join(parts)
    notes = pet.get("notes", "")
    for attack in values["attacks"]:
        loose = re.compile(re.escape(attack["name"]) + r":\s*AT.*?RW\s+[A-Za-z]+", re.S)
        if loose.search(notes):
            notes = loose.sub(lambda _: canonical_attack(attack), notes, count=1)
        else:
            notes = f"{canonical_attack(attack)}; {notes}" if notes else canonical_attack(attack)
    pet["notes"] = notes


def amend(export, companions, fix=False):
    """Check every companion; on success add export['hesindion']. Returns errors."""
    errors, block = [], {}
    by_name = {}
    for key, pet in export.get("pets", {}).items():
        by_name.setdefault(pet.get("name"), []).append(key)
    for name, build in companions.get("pets", {}).items():
        keys = by_name.get(name, [])
        if len(keys) != 1:
            errors.append(f"{name}: no pet named {name!r} in the export" if not keys
                          else f"{name}: {len(keys)} pets share this name in the export")
            continue
        pet = export["pets"][keys[0]]
        values = dict(build.get("values", {}))
        for key in VALUE_LISTS:
            values.setdefault(key, [])
        ap_total = build.get("ap", {}).get("total")
        purchases = []
        for purchase in build.get("purchases", []):
            try:
                purchases.append(normalise(purchase))
            except BuildError as error:
                errors.append(f"{name}: {error}")
        spent = sum(p["ap"] for p in purchases)
        if spent != ap_total:
            errors.append(f"{name}: purchases sum to {spent} AP, ap.total is {ap_total}")
        ko = values.get("attributes", {}).get("ko")
        bought = sum(p["count"] for p in purchases if p["kind"] == "buy")
        if ko is not None and bought > ko:
            errors.append(f"{name}: bought LeP {bought} exceed KO {ko}")
        errors += check_attacks(name, values)
        if fix:
            fix_export(pet, values, ap_total)
        errors += check_export(name, pet, values, ap_total)
        block[keys[0]] = {"name": name, "breed": build.get("breed"),
                          "ap": {"total": ap_total, "spent": spent},
                          "purchases": purchases, "values": values}
    if not errors:
        export.pop("hesindion", None)
        export["hesindion"] = {"schemaVersion": 1, "pets": block}
    return errors


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("export")
    parser.add_argument("--companions")
    parser.add_argument("--out")
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--fix", action="store_true")
    args = parser.parse_args(argv)
    companions_path = args.companions or os.path.splitext(args.export)[0] + ".companions.yaml"
    with open(args.export, encoding="utf-8") as f:
        export = json.load(f)
    with open(companions_path, encoding="utf-8") as f:
        companions = yaml.safe_load(f)
    errors = amend(export, companions, fix=args.fix)
    for error in errors:
        print(error, file=sys.stderr)
    if errors:
        return 1
    if not args.check:
        with open(args.out or args.export, "w", encoding="utf-8") as f:
            f.write(json.dumps(export, ensure_ascii=False, separators=(",", ":")))
    print(f"ok: {len(companions.get('pets', {}))} companion(s)"
          + ("" if args.check else f" written to {args.out or args.export}"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
