# Rules Database Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Build a Python script that transforms DSA YAML source data into a normalized SQLite database, and a Swift service that loads it at runtime for searchable rule lookups.

**Architecture:** A build-time Python script reads `dsa_companion_data` YAML files (de-DE locale + univ mechanics), merges them by ID, and outputs a `rules.db` SQLite file. The iOS app bundles this DB and queries it via a lightweight `RulesDatabase` service using Foundation's SQLite3 C API. Hand-authored mechanical effects live in `specs/data/rules.yaml` and are imported as a separate layer.

**Tech Stack:** Python 3 + PyYAML (venv), SQLite3, Swift/SwiftUI, SQLite3 C API (libsqlite3)

**Source data location:** `/Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data/`

---

## Task 0: Set up Python build script project

**Files:**
- Create: `scripts/build_rules_db/requirements.txt`
- Create: `scripts/build_rules_db/build_db.py`
- Modify: `.gitignore`

**Step 1: Create directory and requirements.txt**

```
scripts/build_rules_db/requirements.txt
```
```
pyyaml>=6.0
```

**Step 2: Create venv and install dependencies**

```bash
cd scripts/build_rules_db
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

**Step 3: Add venv to .gitignore**

Append to `.gitignore`:
```
scripts/build_rules_db/venv/
```

**Step 4: Create skeleton build_db.py**

```python
#!/usr/bin/env python3
"""Build rules.db from DSA YAML source data."""

import argparse
import sqlite3
from pathlib import Path

import yaml


def parse_args():
    p = argparse.ArgumentParser(description="Build rules.db from DSA YAML data")
    p.add_argument("--source", required=True, type=Path,
                    help="Path to dsa_companion_data/Data/ directory")
    p.add_argument("--effects", required=True, type=Path,
                    help="Path to specs/data/rules.yaml")
    p.add_argument("--output", default=Path("rules.db"), type=Path,
                    help="Output SQLite database path")
    return p.parse_args()


def main():
    args = parse_args()
    assert args.source.is_dir(), f"Source directory not found: {args.source}"
    assert args.effects.is_file(), f"Effects file not found: {args.effects}"

    conn = sqlite3.connect(str(args.output))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA foreign_keys=ON")

    create_schema(conn)
    # import steps will be added in subsequent tasks
    conn.close()
    print(f"Built {args.output} successfully.")


if __name__ == "__main__":
    main()
```

**Step 5: Verify it runs**

```bash
source venv/bin/activate
python build_db.py --source /Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data \
  --effects ../../specs/data/rules.yaml \
  --output rules.db
```
Expected: error about `create_schema` not defined (that's Task 1).

**Step 6: Commit**

```bash
git add scripts/build_rules_db/requirements.txt scripts/build_rules_db/build_db.py .gitignore
git commit -m "feat: scaffold Python build script for rules database"
```

---

## Task 1: Implement SQLite schema creation

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add create_schema function**

```python
def create_schema(conn: sqlite3.Connection):
    conn.executescript("""
        CREATE TABLE IF NOT EXISTS locales (
            code TEXT PRIMARY KEY
        );

        CREATE TABLE IF NOT EXISTS sources (
            id   TEXT PRIMARY KEY,
            name TEXT
        );

        CREATE TABLE IF NOT EXISTS categories (
            id   TEXT PRIMARY KEY,
            name TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS groups (
            id       INTEGER PRIMARY KEY,
            category TEXT NOT NULL REFERENCES categories(id),
            name     TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS rules (
            id           TEXT PRIMARY KEY,
            category     TEXT NOT NULL REFERENCES categories(id),
            group_id     INTEGER REFERENCES groups(id),
            subgroup_id  INTEGER,
            cost         TEXT,
            levels       INTEGER,
            max          INTEGER DEFAULT 1,
            is_active    BOOLEAN,
            has_no_parry BOOLEAN
        );

        CREATE TABLE IF NOT EXISTS rules_i18n (
            rule_id     TEXT NOT NULL REFERENCES rules(id),
            locale      TEXT NOT NULL REFERENCES locales(code),
            name        TEXT NOT NULL,
            description TEXT,
            level1      TEXT,
            level2      TEXT,
            level3      TEXT,
            level4      TEXT,
            PRIMARY KEY (rule_id, locale)
        );

        CREATE TABLE IF NOT EXISTS prerequisites (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_id TEXT NOT NULL REFERENCES rules(id),
            type    TEXT NOT NULL,
            ref_id  TEXT,
            value   INTEGER,
            active  BOOLEAN,
            level   INTEGER,
            sid     TEXT
        );

        CREATE TABLE IF NOT EXISTS rule_combat_techniques (
            rule_id             TEXT NOT NULL REFERENCES rules(id),
            combat_technique_id TEXT NOT NULL REFERENCES rules(id),
            PRIMARY KEY (rule_id, combat_technique_id)
        );

        CREATE TABLE IF NOT EXISTS combat_technique_details (
            rule_id          TEXT PRIMARY KEY REFERENCES rules(id),
            improvement_cost TEXT,
            primary_attr_1   TEXT,
            primary_attr_2   TEXT,
            base_parry       INTEGER,
            group_id         INTEGER
        );

        CREATE TABLE IF NOT EXISTS skill_details (
            rule_id          TEXT PRIMARY KEY REFERENCES rules(id),
            check_attr_1     TEXT,
            check_attr_2     TEXT,
            check_attr_3     TEXT,
            improvement_cost TEXT,
            encumbrance      TEXT,
            group_id         INTEGER
        );

        CREATE TABLE IF NOT EXISTS effects (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            rule_id     TEXT NOT NULL REFERENCES rules(id),
            level       INTEGER,
            type        TEXT NOT NULL,
            attribute   TEXT,
            value       REAL,
            scope       TEXT,
            target      TEXT,
            condition   TEXT,
            description TEXT
        );

        CREATE VIRTUAL TABLE IF NOT EXISTS rules_fts USING fts5(
            rule_id,
            name,
            description,
            content='rules_i18n',
            tokenize='unicode61'
        );

        CREATE INDEX IF NOT EXISTS idx_rules_category ON rules(category);
        CREATE INDEX IF NOT EXISTS idx_rules_group ON rules(group_id);
        CREATE INDEX IF NOT EXISTS idx_rules_i18n_locale ON rules_i18n(locale);
        CREATE INDEX IF NOT EXISTS idx_prerequisites_rule ON prerequisites(rule_id);
        CREATE INDEX IF NOT EXISTS idx_effects_rule ON effects(rule_id);
    """)
    conn.commit()
```

**Step 2: Seed categories and locale**

```python
def seed_base_data(conn: sqlite3.Connection):
    categories = [
        ("condition", "Zustand (leveled)"),
        ("state", "Status (binary)"),
        ("advantage", "Vorteil"),
        ("disadvantage", "Nachteil"),
        ("special_ability", "Sonderfertigkeit"),
        ("combat_technique", "Kampftechnik"),
        ("skill", "Talent"),
    ]
    conn.executemany("INSERT OR IGNORE INTO categories VALUES (?, ?)", categories)
    conn.execute("INSERT OR IGNORE INTO locales VALUES (?)", ("de-DE",))
    conn.commit()
```

Add call in `main()`:
```python
    create_schema(conn)
    seed_base_data(conn)
```

**Step 3: Run and verify**

```bash
python build_db.py --source /Users/SamuelvonBaussnern/proj/50_priv/dsa_companion_data/Data \
  --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db ".tables"
```
Expected: all tables listed.

**Step 4: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: add SQLite schema creation for rules database"
```

---

## Task 2: Import conditions and states

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add YAML loading helper**

```python
def load_yaml(path: Path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)
```

**Step 2: Add import_conditions function**

```python
def import_conditions(conn: sqlite3.Connection, source: Path):
    data = load_yaml(source / "de-DE" / "Conditions.yaml")
    for entry in data:
        rule_id = entry["id"]
        conn.execute(
            "INSERT OR REPLACE INTO rules (id, category, levels, max) VALUES (?, 'condition', 4, 1)",
            (rule_id,),
        )
        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n
               (rule_id, locale, name, description, level1, level2, level3, level4)
               VALUES (?, 'de-DE', ?, ?, ?, ?, ?, ?)""",
            (
                rule_id,
                entry.get("name", ""),
                entry.get("description", ""),
                entry.get("level1", ""),
                entry.get("level2", ""),
                entry.get("level3", ""),
                entry.get("level4", ""),
            ),
        )
    conn.commit()
    print(f"  Imported {len(data)} conditions")
```

**Step 3: Add import_states function**

```python
def import_states(conn: sqlite3.Connection, source: Path):
    data = load_yaml(source / "de-DE" / "States.yaml")
    for entry in data:
        rule_id = entry["id"]
        conn.execute(
            "INSERT OR REPLACE INTO rules (id, category) VALUES (?, 'state')",
            (rule_id,),
        )
        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n
               (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("description", "")),
        )
    conn.commit()
    print(f"  Imported {len(data)} states")
```

**Step 4: Wire into main()**

```python
    print("Importing conditions...")
    import_conditions(conn, args.source)
    print("Importing states...")
    import_states(conn, args.source)
```

**Step 5: Run and verify**

```bash
python build_db.py --source /path/to/Data --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='condition'"
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='state'"
```
Expected: 14 conditions, 25 states.

**Step 6: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: import conditions and states into rules database"
```

---

## Task 3: Import advantages and disadvantages

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add import_advantages function**

Merges de-DE (names, rules text) with univ (cost, levels, max, prerequisites).

```python
import json

def import_advantages(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "Advantages.yaml")
    univ_data = load_yaml(source / "univ" / "Advantages.yaml")

    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        cost = univ.get("cost")
        cost_str = json.dumps(cost) if isinstance(cost, list) else str(cost) if cost is not None else None

        conn.execute(
            """INSERT OR REPLACE INTO rules (id, category, cost, levels, max, group_id)
               VALUES (?, 'advantage', ?, ?, ?, ?)""",
            (rule_id, cost_str, univ.get("levels"), univ.get("max", 1), univ.get("gr")),
        )
        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("rules", "")),
        )
        _import_prerequisites(conn, rule_id, univ)

    conn.commit()
    print(f"  Imported {len(de_data)} advantages")
```

**Step 2: Add shared prerequisite importer**

```python
def _import_prerequisites(conn: sqlite3.Connection, rule_id: str, univ: dict):
    for prereq in univ.get("increasablePrerequisites", []):
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, ref_id, value) VALUES (?, 'attribute', ?, ?)",
            (rule_id, prereq["id"], prereq["value"]),
        )
    for prereq in univ.get("activatablePrerequisites", []):
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, ref_id, active, sid) VALUES (?, 'activatable', ?, ?, ?)",
            (rule_id, prereq["id"], prereq.get("active", True), prereq.get("sid")),
        )
    for lp in univ.get("levelPrerequisites", []):
        level = lp.get("level")
        for prereq in lp.get("increasablePrerequisites", []):
            conn.execute(
                "INSERT INTO prerequisites (rule_id, type, ref_id, value, level) VALUES (?, 'attribute', ?, ?, ?)",
                (rule_id, prereq["id"], prereq["value"], level),
            )
        for prereq in lp.get("activatablePrerequisites", []):
            conn.execute(
                "INSERT INTO prerequisites (rule_id, type, ref_id, active, level, sid) VALUES (?, 'activatable', ?, ?, ?, ?)",
                (rule_id, prereq["id"], prereq.get("active", True), level, prereq.get("sid")),
            )
    if "racePrerequisite" in univ:
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, ref_id) VALUES (?, 'race', ?)",
            (rule_id, str(univ["racePrerequisite"])),
        )
    if "socialStatusPrerequisite" in univ:
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, value) VALUES (?, 'social_status', ?)",
            (rule_id, univ["socialStatusPrerequisite"]),
        )
```

**Step 3: Add import_disadvantages (same pattern)**

```python
def import_disadvantages(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "Disadvantages.yaml")
    univ_data = load_yaml(source / "univ" / "Disadvantages.yaml")

    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        cost = univ.get("cost")
        cost_str = json.dumps(cost) if isinstance(cost, list) else str(cost) if cost is not None else None

        conn.execute(
            """INSERT OR REPLACE INTO rules (id, category, cost, levels, max, group_id)
               VALUES (?, 'disadvantage', ?, ?, ?, ?)""",
            (rule_id, cost_str, univ.get("levels"), univ.get("max", 1), univ.get("gr")),
        )
        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("rules", "")),
        )
        _import_prerequisites(conn, rule_id, univ)

    conn.commit()
    print(f"  Imported {len(de_data)} disadvantages")
```

**Step 4: Wire into main() and run**

```bash
python build_db.py --source /path/to/Data --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='advantage'"
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='disadvantage'"
sqlite3 rules.db "SELECT COUNT(*) FROM prerequisites"
```
Expected: ~140 advantages, ~86 disadvantages, prerequisites populated.

**Step 5: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: import advantages and disadvantages into rules database"
```

---

## Task 4: Import special abilities

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Seed special ability groups**

```python
def seed_groups(conn: sqlite3.Connection, source: Path):
    sa_groups = load_yaml(source / "de-DE" / "SpecialAbilityGroups.yaml")
    for g in sa_groups:
        conn.execute(
            "INSERT OR IGNORE INTO groups (id, category, name) VALUES (?, 'special_ability', ?)",
            (g["id"], g["name"]),
        )

    combat_sa_groups = load_yaml(source / "de-DE" / "CombatSpecialAbilityGroups.yaml")
    for g in combat_sa_groups:
        conn.execute(
            "INSERT OR IGNORE INTO groups (id, category, name) VALUES (?, 'special_ability', ?)",
            (1000 + g["id"], g["name"]),  # offset to avoid collision
        )

    skill_groups = load_yaml(source / "de-DE" / "SkillGroups.yaml")
    for g in skill_groups:
        conn.execute(
            "INSERT OR IGNORE INTO groups (id, category, name) VALUES (?, 'skill', ?)",
            (2000 + g["id"], g.get("fullName", g["name"])),
        )

    ct_groups = load_yaml(source / "de-DE" / "CombatTechniqueGroups.yaml")
    for g in ct_groups:
        conn.execute(
            "INSERT OR IGNORE INTO groups (id, category, name) VALUES (?, 'combat_technique', ?)",
            (3000 + g["id"], g["name"]),
        )

    conn.commit()
```

Call from main() before imports.

**Step 2: Add import_special_abilities function**

```python
def import_special_abilities(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "SpecialAbilities.yaml")
    univ_data = load_yaml(source / "univ" / "SpecialAbilities.yaml")

    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        cost = univ.get("cost")
        cost_str = json.dumps(cost) if isinstance(cost, list) else str(cost) if cost is not None else None

        conn.execute(
            """INSERT OR REPLACE INTO rules
               (id, category, group_id, subgroup_id, cost, levels, max)
               VALUES (?, 'special_ability', ?, ?, ?, ?, ?)""",
            (
                rule_id,
                univ.get("gr"),
                univ.get("subgr"),
                cost_str,
                univ.get("levels"),
                univ.get("max", 1),
            ),
        )

        description = entry.get("rules", "") or entry.get("effect", "")
        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), description),
        )

        _import_prerequisites(conn, rule_id, univ)

        # Combat technique associations
        for ct_id in univ.get("combatTechniques", []):
            if isinstance(ct_id, str):
                conn.execute(
                    "INSERT OR IGNORE INTO rule_combat_techniques VALUES (?, ?)",
                    (rule_id, ct_id),
                )

    conn.commit()
    print(f"  Imported {len(de_data)} special abilities")
```

**Step 3: Run and verify**

```bash
python build_db.py --source /path/to/Data --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='special_ability'"
sqlite3 rules.db "SELECT COUNT(*) FROM rule_combat_techniques"
sqlite3 rules.db "SELECT name FROM rules_i18n WHERE rule_id='SA_48'"  -- Finte
```
Expected: 700+ special abilities, combat technique links populated, "Finte" found.

**Step 4: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: import special abilities into rules database"
```

---

## Task 5: Import combat techniques and skills

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add import_combat_techniques**

```python
def import_combat_techniques(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "CombatTechniques.yaml")
    univ_data = load_yaml(source / "univ" / "CombatTechniques.yaml")

    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        conn.execute(
            """INSERT OR REPLACE INTO rules
               (id, category, group_id, has_no_parry)
               VALUES (?, 'combat_technique', ?, ?)""",
            (rule_id, 3000 + univ.get("gr", 1), univ.get("hasNoParry", False)),
        )

        description = entry.get("special", "")
        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), description),
        )

        primary = univ.get("primary", [])
        conn.execute(
            """INSERT OR REPLACE INTO combat_technique_details
               (rule_id, improvement_cost, primary_attr_1, primary_attr_2, base_parry, group_id)
               VALUES (?, ?, ?, ?, ?, ?)""",
            (
                rule_id,
                univ.get("ic"),
                primary[0] if len(primary) > 0 else None,
                primary[1] if len(primary) > 1 else None,
                univ.get("bpr"),
                univ.get("gr"),
            ),
        )

    conn.commit()
    print(f"  Imported {len(de_data)} combat techniques")
```

**Step 2: Add import_skills**

```python
def import_skills(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "Skills.yaml")
    univ_data = load_yaml(source / "univ" / "Skills.yaml")

    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        conn.execute(
            """INSERT OR REPLACE INTO rules
               (id, category, group_id)
               VALUES (?, 'skill', ?)""",
            (rule_id, 2000 + univ.get("gr", 1)),
        )

        # Build description from applications, quality, failed, critical, botch
        parts = []
        for app in entry.get("applications", []):
            parts.append(f"- {app.get('name', '')}")
        if entry.get("quality"):
            parts.append(f"\nQualität: {entry['quality']}")
        if entry.get("failed"):
            parts.append(f"\nMisslungen: {entry['failed']}")
        if entry.get("critical"):
            parts.append(f"\nKritischer Erfolg: {entry['critical']}")
        if entry.get("botch"):
            parts.append(f"\nPatzer: {entry['botch']}")
        description = "\n".join(parts)

        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), description),
        )

        conn.execute(
            """INSERT OR REPLACE INTO skill_details
               (rule_id, check_attr_1, check_attr_2, check_attr_3,
                improvement_cost, encumbrance, group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?)""",
            (
                rule_id,
                univ.get("check1"),
                univ.get("check2"),
                univ.get("check3"),
                univ.get("ic"),
                str(univ.get("enc", "")),
                univ.get("gr"),
            ),
        )

    conn.commit()
    print(f"  Imported {len(de_data)} skills")
```

**Step 3: Wire into main() and run**

```bash
python build_db.py --source /path/to/Data --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='combat_technique'"
sqlite3 rules.db "SELECT COUNT(*) FROM rules WHERE category='skill'"
sqlite3 rules.db "SELECT * FROM combat_technique_details WHERE rule_id='CT_12'"  -- Schwerter
```
Expected: 21 combat techniques, 59 skills, Schwerter details populated.

**Step 4: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: import combat techniques and skills into rules database"
```

---

## Task 6: Import hand-authored effects from rules.yaml

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add name-to-ID mapping**

The hand-authored effects reference rules by name (e.g. "Finte"), but the DB uses IDs (e.g. "SA_48"). Build a reverse lookup from the already-imported rules_i18n data.

```python
def build_name_to_id(conn: sqlite3.Connection) -> dict:
    rows = conn.execute("SELECT rule_id, name FROM rules_i18n WHERE locale='de-DE'").fetchall()
    return {name: rule_id for rule_id, name in rows}
```

**Step 2: Add import_effects function**

Parse the multi-document YAML (separated by `---`) and map each section's entries.

```python
def import_effects(conn: sqlite3.Connection, effects_path: Path, name_to_id: dict):
    with open(effects_path, "r", encoding="utf-8") as f:
        docs = list(yaml.safe_load_all(f))

    count = 0
    for doc in docs:
        if doc is None:
            continue
        for section_key, entries in doc.items():
            if not isinstance(entries, list):
                continue
            for entry in entries:
                name = entry.get("name", "")
                rule_id = name_to_id.get(name)
                if not rule_id:
                    print(f"  WARNING: no DB match for effect rule '{name}', skipping")
                    continue

                effects_list = entry.get("effects", [])
                # Handle both flat effects and level-grouped effects
                for item in effects_list:
                    if "level" in item and "effects" in item:
                        # Level-grouped (playerStates pattern)
                        level = item["level"]
                        for eff in item["effects"]:
                            _insert_effect(conn, rule_id, level, eff)
                            count += 1
                    elif "type" in item:
                        # Flat effect
                        _insert_effect(conn, rule_id, None, item)
                        count += 1

                # Handle combatAbilities with rules array
                for rule_block in entry.get("rules", []):
                    level = rule_block.get("level")
                    for eff in rule_block.get("effects", []):
                        _insert_effect(conn, rule_id, level, eff)
                        count += 1

    conn.commit()
    print(f"  Imported {count} effects")


def _insert_effect(conn: sqlite3.Connection, rule_id: str, level, eff: dict):
    conn.execute(
        """INSERT INTO effects (rule_id, level, type, attribute, value, scope, target, condition, description)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)""",
        (
            rule_id,
            level,
            eff.get("type", ""),
            eff.get("attribute"),
            eff.get("value"),
            eff.get("scope"),
            eff.get("target"),
            eff.get("condition"),
            eff.get("description"),
        ),
    )
```

**Step 3: Wire into main() after all imports**

```python
    name_to_id = build_name_to_id(conn)
    print("Importing hand-authored effects...")
    import_effects(conn, args.effects, name_to_id)
```

**Step 4: Run and verify**

```bash
python build_db.py --source /path/to/Data --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db "SELECT COUNT(*) FROM effects"
sqlite3 rules.db "SELECT * FROM effects WHERE rule_id=(SELECT rule_id FROM rules_i18n WHERE name='Schmerz' LIMIT 1)"
```
Expected: effects populated, Schmerz shows 4 levels of modifiers.

**Step 5: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: import hand-authored effects from rules.yaml"
```

---

## Task 7: Build FTS index and finalize DB

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add FTS population function**

```python
def build_fts_index(conn: sqlite3.Connection):
    conn.execute("""
        INSERT INTO rules_fts (rule_id, name, description)
        SELECT rule_id, name, COALESCE(description, '') FROM rules_i18n
    """)
    conn.commit()
    print("  Built FTS index")
```

**Step 2: Add summary stats**

```python
def print_stats(conn: sqlite3.Connection):
    cats = conn.execute(
        "SELECT category, COUNT(*) FROM rules GROUP BY category ORDER BY category"
    ).fetchall()
    print("\nDatabase summary:")
    for cat, count in cats:
        print(f"  {cat}: {count}")
    effects_count = conn.execute("SELECT COUNT(*) FROM effects").fetchone()[0]
    prereqs_count = conn.execute("SELECT COUNT(*) FROM prerequisites").fetchone()[0]
    print(f"  effects: {effects_count}")
    print(f"  prerequisites: {prereqs_count}")
```

**Step 3: Wire into main() and run full build**

```python
    print("Building FTS index...")
    build_fts_index(conn)
    print_stats(conn)
    conn.close()
```

**Step 4: Test FTS search**

```bash
sqlite3 rules.db "SELECT rule_id, name FROM rules_fts WHERE rules_fts MATCH 'Finte' LIMIT 5"
sqlite3 rules.db "SELECT rule_id, name FROM rules_fts WHERE rules_fts MATCH 'Kampf' LIMIT 10"
```
Expected: Finte found, Kampf returns multiple combat-related entries.

**Step 5: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat: add FTS index and summary stats to rules database builder"
```

---

## Task 8: Normalize rules.yaml to new effect schema

**Files:**
- Modify: `specs/data/rules.yaml`

Rewrite the entire file to use the normalized effect schema. Remove all metadata that's now imported from source (names, descriptions, AP costs, prerequisites). Keep only the hand-authored mechanical effects, referenced by source ID.

The file becomes a pure effects overlay:

```yaml
# Hand-authored mechanical effects for rules that need structured automation.
# Referenced by source data IDs. All metadata (names, descriptions, costs)
# lives in the source YAML and is imported into rules.db.
#
# Effect schema:
#   type:        modifier | damageModifier | opponentModifier | restriction |
#                incapacitated | narrative | stateGain | recovery | negation | damageRedirect
#   attribute:   at | pa | aw | ini | gs | be | le | ae | tp | <skill name>
#   value:       numeric modifier (null for non-numeric)
#   scope:       all | combat | movement | socialTalents | derived | <custom>
#   target:      for damageRedirect (e.g. shieldSP)
#   condition:   optional trigger condition
#   description: for narrative/complex effects

conditions:
  - id: COND_1  # Belastung
    effects:
      - level: 1
        effects:
          - { type: modifier, attribute: at, value: -1, scope: combat }
          - { type: modifier, attribute: pa, value: -1, scope: combat }
          - { type: modifier, attribute: ini, value: -1, scope: combat }
          - { type: modifier, attribute: gs, value: -1, scope: combat }
          - { type: modifier, attribute: talent, value: -1, scope: movement }
      # ... levels 2-3 scale linearly
      - level: 4
        effects:
          - { type: incapacitated, scope: all }

  - id: COND_2  # Betäubung
    effects:
      - level: 1
        effects:
          - { type: modifier, attribute: all, value: -1, scope: all }
      - level: 2
        effects:
          - { type: modifier, attribute: all, value: -2, scope: all }
      - level: 3
        effects:
          - { type: modifier, attribute: all, value: -3, scope: all }
      - level: 4
        effects:
          - { type: incapacitated, scope: all }

  - id: COND_6  # Schmerz
    effects:
      - level: 1
        effects:
          - { type: modifier, attribute: all, value: -1, scope: all }
          - { type: modifier, attribute: gs, value: -1, scope: all }
      - level: 2
        effects:
          - { type: modifier, attribute: all, value: -2, scope: all }
          - { type: modifier, attribute: gs, value: -2, scope: all }
      - level: 3
        effects:
          - { type: modifier, attribute: all, value: -3, scope: all }
          - { type: modifier, attribute: gs, value: -3, scope: all }
      - level: 4
        effects:
          - { type: incapacitated, scope: all }

advantages:
  - id: ADV_9  # Beidhändig
    effects:
      - { type: negation, attribute: offHandPenalty, scope: all }

  - id: ADV_25  # Hohe Lebenskraft
    effects:
      - { type: modifier, attribute: le, value: 1, scope: derived, description: "per level" }

  - id: ADV_35  # Verbesserte Regeneration
    effects:
      - { type: recovery, attribute: le, value: 1, scope: all, description: "per level per regeneration cycle" }

  - id: ADV_47  # Zäher Hund
    effects:
      - { type: modifier, attribute: painLevel, value: -1, scope: all, description: "ignore highest Schmerz level (not at IV)" }

disadvantages:
  - id: DISADV_33  # Persönlichkeitsschwächen
    effects:
      - { type: modifier, attribute: talent, value: -1, scope: socialTalents, description: "except Einschüchtern and Willenskraft" }

combatAbilities:
  - id: SA_48  # Finte
    effects:
      - level: 1
        effects:
          - { type: modifier, attribute: at, value: -1, scope: combat }
          - { type: opponentModifier, attribute: pa, value: -2, scope: combat }
      - level: 2
        effects:
          - { type: modifier, attribute: at, value: -2, scope: combat }
          - { type: opponentModifier, attribute: pa, value: -4, scope: combat }
      - level: 3
        effects:
          - { type: modifier, attribute: at, value: -3, scope: combat }
          - { type: opponentModifier, attribute: pa, value: -6, scope: combat }

  - id: SA_59  # Schildspalter
    effects:
      - { type: negation, attribute: shieldPaBonus, scope: combat }
      - { type: damageRedirect, target: shieldSP, scope: combat }

  - id: SA_65  # Verteidigungshaltung
    effects:
      - { type: modifier, attribute: pa, value: 4, scope: combat }
      - { type: modifier, attribute: aw, value: 4, scope: combat }
      - { type: restriction, attribute: at, scope: combat, description: "no attacks this round" }

  - id: SA_66  # Vorstoß
    effects:
      - { type: modifier, attribute: at, value: 2, scope: combat }
      - { type: restriction, attribute: defense, scope: combat, description: "no defense this round" }

  - id: SA_67  # Wuchtschlag
    effects:
      - level: 1
        effects:
          - { type: modifier, attribute: at, value: -2, scope: combat }
          - { type: damageModifier, value: 2, scope: combat }
      - level: 2
        effects:
          - { type: modifier, attribute: at, value: -4, scope: combat }
          - { type: damageModifier, value: 4, scope: combat }
      - level: 3
        effects:
          - { type: modifier, attribute: at, value: -6, scope: combat }
          - { type: damageModifier, value: 6, scope: combat }

  - id: SA_661  # Golgariten-Stil
    effects:
      - { type: modifier, attribute: at, value: 2, scope: combat, condition: "mounted vs foot fighter" }
      - { type: modifier, attribute: pa, value: 1, scope: combat, condition: "mounted" }

  - id: SA_41  # Belastungsgewöhnung
    effects:
      - { type: modifier, attribute: be, value: -2, scope: combat, description: "per level, reduces effective BE for INI/GS" }

  - id: SA_40  # Aufmerksamkeit
    effects:
      - { type: modifier, attribute: sinnesschaerfe, value: 2, scope: combat, condition: "ambush detection" }
```

Note: The actual IDs (ADV_9, ADV_25, etc.) need to be verified against the source data during implementation. The import_effects function in the build script will match by ID.

**Step 1: Rewrite rules.yaml with normalized schema and source IDs**

Verify IDs by cross-referencing:
```bash
sqlite3 rules.db "SELECT rule_id FROM rules_i18n WHERE name='Beidhändig'"
sqlite3 rules.db "SELECT rule_id FROM rules_i18n WHERE name='Hohe Lebenskraft'"
# etc.
```

**Step 2: Run full build and verify effects imported correctly**

```bash
python build_db.py --source /path/to/Data --effects ../../specs/data/rules.yaml --output rules.db
sqlite3 rules.db "SELECT * FROM effects ORDER BY rule_id, level"
```

**Step 3: Commit**

```bash
git add specs/data/rules.yaml
git commit -m "refactor: normalize rules.yaml to unified effect schema with source IDs"
```

---

## Task 9: Add Swift RulesDatabase service

**Files:**
- Create: `Hesindion/Services/RulesDatabase.swift`
- Modify: Xcode project to add `rules.db` to bundle resources

**Step 1: Copy rules.db into Xcode project**

```bash
cp scripts/build_rules_db/rules.db Hesindion/Resources/rules.db
```

Add `rules.db` to the Xcode project's "Copy Bundle Resources" build phase.

**Step 2: Create RulesDatabase.swift**

```swift
import Foundation
import SQLite3

struct RuleSearchResult: Identifiable {
    let id: String       // e.g. "SA_48"
    let category: String // e.g. "special_ability"
    let name: String
    let description: String
}

struct RuleDetail {
    let id: String
    let category: String
    let name: String
    let description: String
    let cost: String?
    let levels: Int?
    let max: Int?
    let effects: [RuleEffect]
}

struct RuleEffect {
    let level: Int?
    let type: String
    let attribute: String?
    let value: Double?
    let scope: String?
    let description: String?
}

final class RulesDatabase {
    static let shared = RulesDatabase()

    private var db: OpaquePointer?

    private init() {
        guard let path = Bundle.main.path(forResource: "rules", ofType: "db") else {
            fatalError("rules.db not found in bundle")
        }
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            fatalError("Cannot open rules.db")
        }
    }

    deinit {
        sqlite3_close(db)
    }

    func search(query: String, locale: String = "de-DE", limit: Int = 20) -> [RuleSearchResult] {
        let sql = """
            SELECT f.rule_id, r.category, f.name, f.description
            FROM rules_fts f
            JOIN rules r ON r.id = f.rule_id
            WHERE rules_fts MATCH ?
            LIMIT ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        let ftsQuery = query.split(separator: " ").map { "\($0)*" }.joined(separator: " ")
        sqlite3_bind_text(stmt, 1, ftsQuery, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_int(stmt, 2, Int32(limit))

        var results: [RuleSearchResult] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RuleSearchResult(
                id: String(cString: sqlite3_column_text(stmt, 0)),
                category: String(cString: sqlite3_column_text(stmt, 1)),
                name: String(cString: sqlite3_column_text(stmt, 2)),
                description: sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
            ))
        }
        return results
    }

    func lookup(id: String, locale: String = "de-DE") -> RuleDetail? {
        let sql = """
            SELECT r.id, r.category, i.name, i.description, r.cost, r.levels, r.max
            FROM rules r
            JOIN rules_i18n i ON i.rule_id = r.id AND i.locale = ?
            WHERE r.id = ?
            """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, locale, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
        sqlite3_bind_text(stmt, 2, id, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }

        let ruleId = String(cString: sqlite3_column_text(stmt, 0))
        let category = String(cString: sqlite3_column_text(stmt, 1))
        let name = String(cString: sqlite3_column_text(stmt, 2))
        let desc = sqlite3_column_text(stmt, 3).map { String(cString: $0) } ?? ""
        let cost = sqlite3_column_text(stmt, 4).map { String(cString: $0) }
        let levels = sqlite3_column_type(stmt, 5) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 5)) : nil
        let max = sqlite3_column_type(stmt, 6) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 6)) : nil

        let effects = lookupEffects(ruleId: ruleId)

        return RuleDetail(
            id: ruleId, category: category, name: name, description: desc,
            cost: cost, levels: levels, max: max, effects: effects
        )
    }

    private func lookupEffects(ruleId: String) -> [RuleEffect] {
        let sql = "SELECT level, type, attribute, value, scope, description FROM effects WHERE rule_id = ? ORDER BY level"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, ruleId, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))

        var results: [RuleEffect] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(RuleEffect(
                level: sqlite3_column_type(stmt, 0) != SQLITE_NULL ? Int(sqlite3_column_int(stmt, 0)) : nil,
                type: String(cString: sqlite3_column_text(stmt, 1)),
                attribute: sqlite3_column_text(stmt, 2).map { String(cString: $0) },
                value: sqlite3_column_type(stmt, 3) != SQLITE_NULL ? sqlite3_column_double(stmt, 3) : nil,
                scope: sqlite3_column_text(stmt, 4).map { String(cString: $0) },
                description: sqlite3_column_text(stmt, 5).map { String(cString: $0) }
            ))
        }
        return results
    }
}
```

**Step 3: Verify it compiles**

```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build
```

**Step 4: Commit**

```bash
git add Hesindion/Services/RulesDatabase.swift Hesindion/Resources/rules.db
git commit -m "feat: add RulesDatabase service for SQLite rule lookups"
```

---

## Task 10: Add Swift Rule model and search integration

**Files:**
- Modify: `Hesindion/Views/CommandPaletteOverlay.swift`

**Step 1: Add a "Regel nachschlagen" command to the command palette**

Read `CommandPaletteOverlay.swift` to understand the existing command pattern, then add a rule search mode that queries `RulesDatabase.shared.search()` as the user types.

**Step 2: Add a rule detail sheet**

When a rule search result is tapped, show a sheet with the full rule detail from `RulesDatabase.shared.lookup()`.

**Step 3: Verify build and test manually**

```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build
```

**Step 4: Commit**

```bash
git add Hesindion/Views/CommandPaletteOverlay.swift
git commit -m "feat: add rule search to command palette"
```
