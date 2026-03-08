#!/usr/bin/env python3
"""Build rules.db from DSA YAML source data."""

import argparse
import json
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

        CREATE TABLE IF NOT EXISTS spell_details (
            rule_id            TEXT PRIMARY KEY REFERENCES rules(id),
            check_attr_1       TEXT,
            check_attr_2       TEXT,
            check_attr_3       TEXT,
            improvement_cost   TEXT,
            casting_time       TEXT,
            casting_time_short TEXT,
            ae_cost            TEXT,
            ae_cost_short      TEXT,
            range              TEXT,
            range_short        TEXT,
            duration           TEXT,
            duration_short     TEXT,
            target             TEXT,
            property           INTEGER,
            tradition_ids      TEXT,
            group_id           INTEGER
        );

        CREATE INDEX IF NOT EXISTS idx_spell_details_property ON spell_details(property);
        CREATE INDEX IF NOT EXISTS idx_spell_details_group ON spell_details(group_id);

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


def load_yaml(path: Path):
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def seed_base_data(conn: sqlite3.Connection):
    categories = [
        ("condition", "Zustand (leveled)"),
        ("state", "Status (binary)"),
        ("advantage", "Vorteil"),
        ("disadvantage", "Nachteil"),
        ("special_ability", "Sonderfertigkeit"),
        ("combat_technique", "Kampftechnik"),
        ("skill", "Talent"),
        ("spell", "Zauber"),
        ("liturgy", "Liturgie"),
    ]
    conn.executemany("INSERT OR IGNORE INTO categories VALUES (?, ?)", categories)
    conn.execute("INSERT OR IGNORE INTO locales VALUES (?)", ("de-DE",))
    conn.commit()


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


def _import_prerequisites(conn: sqlite3.Connection, rule_id: str, univ: dict):
    for prereq in univ.get("increasablePrerequisites", []):
        ref_id = prereq["id"]
        ref_id_str = json.dumps(ref_id) if isinstance(ref_id, list) else ref_id
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, ref_id, value) VALUES (?, 'attribute', ?, ?)",
            (rule_id, ref_id_str, prereq["value"]),
        )
    for prereq in univ.get("activatablePrerequisites", []):
        ref_id = prereq["id"]
        ref_id_str = json.dumps(ref_id) if isinstance(ref_id, list) else ref_id
        sid = prereq.get("sid")
        sid_str = json.dumps(sid) if isinstance(sid, (list, dict)) else sid
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, ref_id, active, sid) VALUES (?, 'activatable', ?, ?, ?)",
            (rule_id, ref_id_str, prereq.get("active", True), sid_str),
        )
    for lp in univ.get("levelPrerequisites", []):
        level = lp.get("level")
        for prereq in lp.get("increasablePrerequisites", []):
            ref_id = prereq["id"]
            ref_id_str = json.dumps(ref_id) if isinstance(ref_id, list) else ref_id
            conn.execute(
                "INSERT INTO prerequisites (rule_id, type, ref_id, value, level) VALUES (?, 'attribute', ?, ?, ?)",
                (rule_id, ref_id_str, prereq["value"], level),
            )
        for prereq in lp.get("activatablePrerequisites", []):
            ref_id = prereq["id"]
            ref_id_str = json.dumps(ref_id) if isinstance(ref_id, list) else ref_id
            sid = prereq.get("sid")
            sid_str = json.dumps(sid) if isinstance(sid, (list, dict)) else sid
            conn.execute(
                "INSERT INTO prerequisites (rule_id, type, ref_id, active, level, sid) VALUES (?, 'activatable', ?, ?, ?, ?)",
                (rule_id, ref_id_str, prereq.get("active", True), level, sid_str),
            )
    if "racePrerequisite" in univ:
        rp = univ["racePrerequisite"]
        ref_id = json.dumps(rp) if isinstance(rp, (dict, list)) else str(rp)
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, ref_id) VALUES (?, 'race', ?)",
            (rule_id, ref_id),
        )
    if "socialStatusPrerequisite" in univ:
        conn.execute(
            "INSERT INTO prerequisites (rule_id, type, value) VALUES (?, 'social_status', ?)",
            (rule_id, univ["socialStatusPrerequisite"]),
        )


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
            (1000 + g["id"], g["name"]),
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

    spell_groups = load_yaml(source / "de-DE" / "SpellGroups.yaml")
    for g in spell_groups:
        conn.execute(
            "INSERT OR IGNORE INTO groups (id, category, name) VALUES (?, 'spell', ?)",
            (4000 + g["id"], g["name"]),
        )

    liturgy_groups = load_yaml(source / "de-DE" / "LiturgicalChantGroups.yaml")
    for g in liturgy_groups:
        conn.execute(
            "INSERT OR IGNORE INTO groups (id, category, name) VALUES (?, 'liturgy', ?)",
            (5000 + g["id"], g["name"]),
        )

    # Sentinel groups for cantrips and blessings
    conn.execute(
        "INSERT OR IGNORE INTO groups (id, category, name) VALUES (4999, 'spell', 'Zaubertricks')"
    )
    conn.execute(
        "INSERT OR IGNORE INTO groups (id, category, name) VALUES (5999, 'liturgy', 'Segnungen')"
    )

    conn.commit()
    print("  Seeded groups")


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

        ct_list = univ.get("combatTechniques", [])
        if isinstance(ct_list, list):
            for ct_id in ct_list:
                if isinstance(ct_id, str):
                    conn.execute(
                        "INSERT OR IGNORE INTO rule_combat_techniques VALUES (?, ?)",
                        (rule_id, ct_id),
                    )

    conn.commit()
    print(f"  Imported {len(de_data)} special abilities")


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

        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("special", "")),
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


def _import_spell_like(conn: sqlite3.Connection, source: Path,
                       de_file: str, univ_file: str, category: str,
                       group_offset: int, cost_key: str = "aeCost",
                       cost_short_key: str = "aeCostShort"):
    de_path = source / "de-DE" / de_file
    univ_path = source / "univ" / univ_file

    de_data = load_yaml(de_path)
    if not de_data:
        print(f"  Skipped {de_file} (empty)")
        return 0

    univ_data = load_yaml(univ_path) or []
    univ_by_id = {e["id"]: e for e in univ_data} if univ_data else {}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        conn.execute(
            """INSERT OR REPLACE INTO rules (id, category, group_id)
               VALUES (?, ?, ?)""",
            (rule_id, category, group_offset + univ.get("gr", 1)),
        )

        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("effect", "")),
        )

        traditions = univ.get("traditions", [])
        # Use property for arcane, first aspect for karmal
        aspects = univ.get("aspects", [])
        prop = univ.get("property") if univ.get("property") is not None else (aspects[0] if aspects else None)

        conn.execute(
            """INSERT OR REPLACE INTO spell_details
               (rule_id, check_attr_1, check_attr_2, check_attr_3,
                improvement_cost, casting_time, casting_time_short,
                ae_cost, ae_cost_short, range, range_short,
                duration, duration_short, target, property, tradition_ids, group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            (
                rule_id,
                univ.get("check1"),
                univ.get("check2"),
                univ.get("check3"),
                univ.get("ic"),
                entry.get("castingTime"),
                entry.get("castingTimeShort"),
                entry.get(cost_key),
                entry.get(cost_short_key),
                entry.get("range"),
                entry.get("rangeShort"),
                entry.get("duration"),
                entry.get("durationShort"),
                entry.get("target"),
                prop,
                json.dumps(traditions) if traditions else None,
                univ.get("gr"),
            ),
        )

        _import_prerequisites(conn, rule_id, univ)

    conn.commit()
    return len(de_data)


def import_spells(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "Spells.yaml", "Spells.yaml",
                               "spell", 4000)
    print(f"  Imported {count} spells")


def import_cantrips(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "Cantrips.yaml")
    univ_data = load_yaml(source / "univ" / "Cantrips.yaml")
    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        conn.execute(
            """INSERT OR REPLACE INTO rules (id, category, group_id)
               VALUES (?, 'spell', 4999)""",
            (rule_id,),
        )

        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("effect", "")),
        )

        traditions = univ.get("traditions", [])
        conn.execute(
            """INSERT OR REPLACE INTO spell_details
               (rule_id, range, range_short, duration, duration_short,
                target, property, tradition_ids, group_id)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, 4999)""",
            (
                rule_id,
                entry.get("range"),
                entry.get("rangeShort"),
                entry.get("duration"),
                entry.get("durationShort"),
                entry.get("target"),
                univ.get("property"),
                json.dumps(traditions) if traditions else None,
            ),
        )

    conn.commit()
    print(f"  Imported {len(de_data)} cantrips")


def import_curses(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "Curses.yaml", "Curses.yaml",
                               "spell", 4000)
    print(f"  Imported {count} curses")


def import_elven_songs(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "ElvenMagicalSongs.yaml",
                               "ElvenMagicalSongs.yaml", "spell", 4000)
    print(f"  Imported {count} elven magical songs")


def import_magical_dances(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "MagicalDances.yaml",
                               "MagicalDances.yaml", "spell", 4000)
    print(f"  Imported {count} magical dances")


def import_magical_melodies(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "MagicalMelodies.yaml",
                               "MagicalMelodies.yaml", "spell", 4000)
    print(f"  Imported {count} magical melodies")


def import_domination_rituals(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "DominationRituals.yaml",
                               "DominationRituals.yaml", "spell", 4000)
    print(f"  Imported {count} domination rituals")


def import_geode_rituals(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "GeodeRituals.yaml",
                               "GeodeRituals.yaml", "spell", 4000)
    print(f"  Imported {count} geode rituals")


def import_zibilja_rituals(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "ZibiljaRituals.yaml",
                               "ZibiljaRituals.yaml", "spell", 4000)
    print(f"  Imported {count} zibilja rituals")


def import_liturgical_chants(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "LiturgicalChants.yaml",
                               "LiturgicalChants.yaml", "liturgy", 5000,
                               cost_key="kpCost", cost_short_key="kpCostShort")
    print(f"  Imported {count} liturgical chants")


def import_blessings(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "Blessings.yaml")

    for entry in de_data:
        rule_id = entry["id"]

        conn.execute(
            """INSERT OR REPLACE INTO rules (id, category, group_id)
               VALUES (?, 'liturgy', 5999)""",
            (rule_id,),
        )

        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("effect", "")),
        )

        conn.execute(
            """INSERT OR REPLACE INTO spell_details
               (rule_id, range, range_short, duration, duration_short, target, group_id)
               VALUES (?, ?, ?, ?, ?, ?, 5999)""",
            (
                rule_id,
                entry.get("range"),
                entry.get("rangeShort"),
                entry.get("duration"),
                entry.get("durationShort"),
                entry.get("target"),
            ),
        )

    conn.commit()
    print(f"  Imported {len(de_data)} blessings")


def import_effects(conn: sqlite3.Connection, effects_path: Path):
    with open(effects_path, "r", encoding="utf-8") as f:
        doc = yaml.safe_load(f)

    if doc is None:
        print("  WARNING: effects file is empty")
        return

    count = 0
    for section_key, entries in doc.items():
        if not isinstance(entries, list):
            continue
        for entry in entries:
            rule_id = entry.get("id")
            if not rule_id:
                continue
            # Verify rule exists in DB
            exists = conn.execute("SELECT 1 FROM rules WHERE id = ?", (rule_id,)).fetchone()
            if not exists:
                print(f"  WARNING: rule_id '{rule_id}' not found in DB, skipping")
                continue

            for item in entry.get("effects", []):
                if "level" in item and "effects" in item:
                    # Level-grouped
                    level = item["level"]
                    for eff in item["effects"]:
                        _insert_effect(conn, rule_id, level, eff)
                        count += 1
                elif "type" in item:
                    # Flat effect
                    _insert_effect(conn, rule_id, None, item)
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


def build_fts_index(conn: sqlite3.Connection):
    conn.execute("""
        INSERT INTO rules_fts (rule_id, name, description)
        SELECT rule_id, name, COALESCE(description, '') FROM rules_i18n
    """)
    conn.commit()
    print("  Built FTS index")


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


def main():
    args = parse_args()
    assert args.source.is_dir(), f"Source directory not found: {args.source}"
    assert args.effects.is_file(), f"Effects file not found: {args.effects}"

    conn = sqlite3.connect(str(args.output))
    conn.execute("PRAGMA journal_mode=DELETE")
    conn.execute("PRAGMA foreign_keys=ON")

    create_schema(conn)
    seed_base_data(conn)

    print("Seeding groups...")
    seed_groups(conn, args.source)

    print("Importing conditions...")
    import_conditions(conn, args.source)
    print("Importing states...")
    import_states(conn, args.source)
    print("Importing advantages...")
    import_advantages(conn, args.source)
    print("Importing disadvantages...")
    import_disadvantages(conn, args.source)
    print("Importing combat techniques...")
    import_combat_techniques(conn, args.source)
    print("Importing special abilities...")
    import_special_abilities(conn, args.source)
    print("Importing skills...")
    import_skills(conn, args.source)

    print("Importing spells...")
    import_spells(conn, args.source)

    print("Importing cantrips...")
    import_cantrips(conn, args.source)

    print("Importing curses...")
    import_curses(conn, args.source)
    print("Importing elven magical songs...")
    import_elven_songs(conn, args.source)
    print("Importing magical dances...")
    import_magical_dances(conn, args.source)
    print("Importing magical melodies...")
    import_magical_melodies(conn, args.source)
    print("Importing domination rituals...")
    import_domination_rituals(conn, args.source)
    print("Importing geode rituals...")
    import_geode_rituals(conn, args.source)
    print("Importing zibilja rituals...")
    import_zibilja_rituals(conn, args.source)

    print("Importing liturgical chants...")
    import_liturgical_chants(conn, args.source)
    print("Importing blessings...")
    import_blessings(conn, args.source)

    print("Importing hand-authored effects...")
    import_effects(conn, args.effects)

    print("Building FTS index...")
    build_fts_index(conn)

    print_stats(conn)

    conn.close()
    print(f"Built {args.output} successfully.")


if __name__ == "__main__":
    main()
