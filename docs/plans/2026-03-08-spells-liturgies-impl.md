# Spells & Liturgies Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:executing-plans to implement this plan task-by-task.

**Goal:** Import all arcane and karmal magic content into the rules database and display spell metadata in the rulebook UI.

**Architecture:** Extend `build_db.py` with 11 new import functions that read from existing YAML sources, add a `spell_details` table for structured spell metadata, and update the Swift layer (`RulesDatabase`, `RuleDetailView`, `RulebookView`, `Strings`) to query and display the new data.

**Tech Stack:** Python 3 + PyYAML (build script), SQLite3 (database), SwiftUI (UI)

---

### Task 0: Add `spell_details` table to schema and seed new categories

**Files:**
- Modify: `scripts/build_rules_db/build_db.py` — `create_schema()` and `seed_base_data()`

**Step 1: Add `spell_details` table to `create_schema()`**

After the `effects` table creation (before `CREATE VIRTUAL TABLE`), add:

```python
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
```

**Step 2: Add new categories to `seed_base_data()`**

Append to the `categories` list:

```python
        ("spell", "Zauber"),
        ("liturgy", "Liturgie"),
```

**Step 3: Add spell/liturgy groups to `seed_groups()`**

After the `ct_groups` block, add:

```python
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
```

**Step 4: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat(rules-db): add spell_details schema and spell/liturgy categories"
```

---

### Task 1: Add `import_spells` function

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add the import function**

Add after `import_skills`:

```python
def import_spells(conn: sqlite3.Connection, source: Path):
    de_data = load_yaml(source / "de-DE" / "Spells.yaml")
    univ_data = load_yaml(source / "univ" / "Spells.yaml")
    univ_by_id = {e["id"]: e for e in univ_data}

    for entry in de_data:
        rule_id = entry["id"]
        univ = univ_by_id.get(rule_id, {})

        conn.execute(
            """INSERT OR REPLACE INTO rules (id, category, group_id)
               VALUES (?, 'spell', ?)""",
            (rule_id, 4000 + univ.get("gr", 1)),
        )

        conn.execute(
            """INSERT OR REPLACE INTO rules_i18n (rule_id, locale, name, description)
               VALUES (?, 'de-DE', ?, ?)""",
            (rule_id, entry.get("name", ""), entry.get("effect", "")),
        )

        traditions = univ.get("traditions", [])
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
                entry.get("aeCost"),
                entry.get("aeCostShort"),
                entry.get("range"),
                entry.get("rangeShort"),
                entry.get("duration"),
                entry.get("durationShort"),
                entry.get("target"),
                univ.get("property"),
                json.dumps(traditions) if traditions else None,
                univ.get("gr"),
            ),
        )

        _import_prerequisites(conn, rule_id, univ)

    conn.commit()
    print(f"  Imported {len(de_data)} spells")
```

**Step 2: Wire into `main()`**

After the `import_skills` call, add:

```python
    print("Importing spells...")
    import_spells(conn, args.source)
```

**Step 3: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat(rules-db): add spell import from Spells.yaml"
```

---

### Task 2: Add `import_cantrips` function

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add the import function**

```python
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
```

**Step 2: Wire into `main()`**

```python
    print("Importing cantrips...")
    import_cantrips(conn, args.source)
```

**Step 3: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat(rules-db): add cantrip import"
```

---

### Task 3: Add arcane sub-type imports (curses, elven songs, dances, melodies, rituals)

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

These all share the same structure as spells but from different YAML files. Add a shared helper and thin wrappers.

**Step 1: Add `_import_spell_like` helper**

```python
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
        property_or_aspect = univ.get("property") or univ.get("aspects", [None])[0] if univ.get("aspects") else univ.get("property")

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
                property_or_aspect,
                json.dumps(traditions) if traditions else None,
                univ.get("gr"),
            ),
        )

        _import_prerequisites(conn, rule_id, univ)

    conn.commit()
    return len(de_data)
```

**Step 2: Refactor `import_spells` to use the helper**

Replace the body of `import_spells` with:

```python
def import_spells(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "Spells.yaml", "Spells.yaml",
                               "spell", 4000)
    print(f"  Imported {count} spells")
```

**Step 3: Add wrapper functions for each sub-type**

```python
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
```

**Step 4: Wire all into `main()`**

After `import_cantrips`:

```python
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
```

**Step 5: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat(rules-db): add imports for curses, elven songs, dances, melodies, rituals"
```

---

### Task 4: Add liturgical chant and blessing imports

**Files:**
- Modify: `scripts/build_rules_db/build_db.py`

**Step 1: Add `import_liturgical_chants`**

Liturgies use `kpCost`/`kpCostShort` instead of `aeCost`/`aeCostShort`, and `aspects` instead of `property`.

```python
def import_liturgical_chants(conn: sqlite3.Connection, source: Path):
    count = _import_spell_like(conn, source, "LiturgicalChants.yaml",
                               "LiturgicalChants.yaml", "liturgy", 5000,
                               cost_key="kpCost", cost_short_key="kpCostShort")
    print(f"  Imported {count} liturgical chants")
```

**Step 2: Add `import_blessings`**

Blessings have no check, no IC — similar to cantrips but for liturgy category.

```python
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
```

**Step 3: Wire into `main()`**

After zibilja rituals:

```python
    print("Importing liturgical chants...")
    import_liturgical_chants(conn, args.source)
    print("Importing blessings...")
    import_blessings(conn, args.source)
```

**Step 4: Commit**

```bash
git add scripts/build_rules_db/build_db.py
git commit -m "feat(rules-db): add liturgical chant and blessing imports"
```

---

### Task 5: Rebuild rules.db and verify

**Files:**
- Regenerate: `scripts/build_rules_db/rules.db`
- Regenerate: `Hesindion/Resources/rules.db`

**Step 1: Run the build script**

```bash
cd scripts/build_rules_db
python3 build_db.py \
  --source ../../dsa_companion_data_path/Data \
  --effects ../../specs/data/rules.yaml \
  --output rules.db
```

Note: The actual path to `dsa_companion_data` needs to be determined. Check the Makefile:

```bash
cat /Users/SamuelvonBaussnern/proj/50_priv/Hesindion/Makefile
```

**Step 2: Verify counts**

Expected output should show `spell` and `liturgy` categories with substantial counts. Run:

```bash
sqlite3 rules.db "SELECT category, COUNT(*) FROM rules GROUP BY category ORDER BY category"
```

Expected approximately:
- `liturgy`: ~200+
- `spell`: ~400+

Also verify spell_details:

```bash
sqlite3 rules.db "SELECT COUNT(*) FROM spell_details"
```

**Step 3: Copy to Resources**

```bash
cp rules.db ../../Hesindion/Resources/rules.db
```

**Step 4: Commit**

Do NOT commit `rules.db` files (they are in `.gitignore`). Just commit the script changes if any fixes were needed.

---

### Task 6: Update `RulesDatabase.swift` — add spell detail fields to `RuleDetail`

**Files:**
- Modify: `Hesindion/Services/RulesDatabase.swift`

**Step 1: Add `SpellDetail` struct and update `RuleDetail`**

After `RuleEffect`, add:

```swift
struct SpellDetail {
    let checkAttr1: String?
    let checkAttr2: String?
    let checkAttr3: String?
    let improvementCost: String?
    let castingTime: String?
    let castingTimeShort: String?
    let aeCost: String?
    let aeCostShort: String?
    let range: String?
    let rangeShort: String?
    let duration: String?
    let durationShort: String?
    let target: String?
}
```

Add to `RuleDetail`:

```swift
let spellDetail: SpellDetail?
```

**Step 2: Add `lookupSpellDetail` query method**

```swift
private func lookupSpellDetail(ruleId: String) -> SpellDetail? {
    let sql = """
        SELECT check_attr_1, check_attr_2, check_attr_3,
               improvement_cost, casting_time, casting_time_short,
               ae_cost, ae_cost_short, range, range_short,
               duration, duration_short, target
        FROM spell_details WHERE rule_id = ?
        """
    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }

    sqlite3_bind_text(stmt, 1, ruleId, -1, SQLITE_TRANSIENT)

    guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
    return SpellDetail(
        checkAttr1: col_text_opt(stmt, 0),
        checkAttr2: col_text_opt(stmt, 1),
        checkAttr3: col_text_opt(stmt, 2),
        improvementCost: col_text_opt(stmt, 3),
        castingTime: col_text_opt(stmt, 4),
        castingTimeShort: col_text_opt(stmt, 5),
        aeCost: col_text_opt(stmt, 6),
        aeCostShort: col_text_opt(stmt, 7),
        range: col_text_opt(stmt, 8),
        rangeShort: col_text_opt(stmt, 9),
        duration: col_text_opt(stmt, 10),
        durationShort: col_text_opt(stmt, 11),
        target: col_text_opt(stmt, 12)
    )
}
```

**Step 3: Wire into `lookup(id:locale:)`**

After `let effects = lookupEffects(ruleId: ruleId)`, add:

```swift
let spellDetail = (category == "spell" || category == "liturgy")
    ? lookupSpellDetail(ruleId: ruleId)
    : nil
```

Update the `RuleDetail` constructor to pass `spellDetail: spellDetail`.

**Step 4: Commit**

```bash
git add Hesindion/Services/RulesDatabase.swift
git commit -m "feat: add SpellDetail struct and query to RulesDatabase"
```

---

### Task 7: Update `RuleDetailView.swift` — render spell metadata

**Files:**
- Modify: `Hesindion/Views/RuleDetailView.swift`

**Step 1: Add spell metadata block**

In the `body`, after the `HStack` with `metaBadge` items and before the description `Text`, add:

```swift
if let spell = rule.spellDetail {
    spellMetaBlock(spell, isLiturgy: rule.category == "liturgy")
}
```

**Step 2: Add `spellMetaBlock` helper**

```swift
private func spellMetaBlock(_ spell: SpellDetail, isLiturgy: Bool) -> some View {
    VStack(alignment: .leading, spacing: 6) {
        if let c1 = spell.checkAttr1,
           let c2 = spell.checkAttr2,
           let c3 = spell.checkAttr3 {
            spellMetaRow(L("spellCheck"), "\(c1)/\(c2)/\(c3)")
        }
        if let ic = spell.improvementCost {
            spellMetaRow(L("spellIC"), ic)
        }
        if let ct = spell.castingTime {
            spellMetaRow(isLiturgy ? L("liturgyTime") : L("spellCastingTime"), ct)
        }
        if let cost = spell.aeCost {
            spellMetaRow(isLiturgy ? L("liturgyCost") : L("spellAeCost"), cost)
        }
        if let range = spell.range {
            spellMetaRow(L("spellRange"), range)
        }
        if let dur = spell.duration {
            spellMetaRow(L("spellDuration"), dur)
        }
        if let target = spell.target {
            spellMetaRow(L("spellTarget"), target)
        }
    }
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.groupRulebook.opacity(0.08))
    .overlay(Rectangle().stroke(Color.black, lineWidth: DSALayout.tertiaryBorder))
}

private func spellMetaRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .top, spacing: 8) {
        Text(label)
            .font(.system(.caption, weight: .bold))
            .frame(width: 100, alignment: .leading)
        Text(value)
            .font(.caption)
    }
}
```

**Step 3: Commit**

```bash
git add Hesindion/Views/RuleDetailView.swift
git commit -m "feat: render spell metadata block in RuleDetailView"
```

---

### Task 8: Update `RulebookView.swift` — add spell/liturgy categories

**Files:**
- Modify: `Hesindion/Views/RulebookView.swift`

**Step 1: Add new categories to `categoryOrder`**

```swift
private let categoryOrder = [
    "advantage", "disadvantage", "special_ability",
    "combat_technique", "skill", "spell", "liturgy",
    "condition", "state"
]
```

**Step 2: Commit**

```bash
git add Hesindion/Views/RulebookView.swift
git commit -m "feat: add spell and liturgy categories to rulebook view"
```

---

### Task 9: Update `Strings.swift` — add i18n keys

**Files:**
- Modify: `Hesindion/Theme/Strings.swift`

**Step 1: Add English strings**

In the English dictionary, after the existing `cat.*` / `cats.*` entries:

```swift
"cat.spell":            "Spell",
"cat.liturgy":          "Liturgy",
"cats.spell":           "Spells",
"cats.liturgy":         "Liturgies",

"spellCheck":           "Check",
"spellIC":              "Improvement Cost",
"spellCastingTime":     "Casting Time",
"spellAeCost":          "AE Cost",
"liturgyTime":          "Liturgy Time",
"liturgyCost":          "KP Cost",
"spellRange":           "Range",
"spellDuration":        "Duration",
"spellTarget":          "Target",
```

**Step 2: Add German strings**

In the German dictionary, after the existing `cat.*` / `cats.*` entries:

```swift
"cat.spell":            "Zauber",
"cat.liturgy":          "Liturgie",
"cats.spell":           "Zauber",
"cats.liturgy":         "Liturgien",

"spellCheck":           "Probe",
"spellIC":              "Steigerungsfaktor",
"spellCastingTime":     "Zauberdauer",
"spellAeCost":          "AsP-Kosten",
"liturgyTime":          "Liturgiedauer",
"liturgyCost":          "KaP-Kosten",
"spellRange":           "Reichweite",
"spellDuration":        "Wirkungsdauer",
"spellTarget":          "Zielkategorie",
```

**Step 3: Commit**

```bash
git add Hesindion/Theme/Strings.swift
git commit -m "feat: add spell/liturgy i18n strings"
```

---

### Task 10: Build and verify in Xcode

**Step 1: Build the project**

```bash
xcodebuild -project Hesindion.xcodeproj -scheme Hesindion -sdk iphonesimulator build
```

**Step 2: Fix any compilation errors**

**Step 3: Final commit if fixes were needed**

```bash
git add -A
git commit -m "fix: resolve build issues for spell/liturgy integration"
```
