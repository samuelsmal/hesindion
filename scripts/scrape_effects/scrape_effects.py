#!/usr/bin/env python3
"""Scrape DSA 5 rule effects from ulisses-regelwiki.de.

Produces a YAML file with structured effects data suitable for import
into the iDSACompanion effects table. Falls back to hardcoded data
for critical combat special abilities when scraping fails.
"""

import argparse
import re
import sys
import time
from pathlib import Path

import requests
import yaml
from bs4 import BeautifulSoup

BASE_URL = "https://dsa.ulisses-regelwiki.de"
HEADERS = {"User-Agent": "DSA-Companion-Scraper/1.0"}
DELAY = 1.0  # polite delay between requests

# ---------------------------------------------------------------------------
# Known rule IDs → wiki page names (German)
# ---------------------------------------------------------------------------
KNOWN_RULES: dict[str, str] = {
    "SA_48": "Finte",
    "SA_67": "Wuchtschlag",
    "SA_66": "Vorstoss",
    "SA_59": "Schildspalter",
    "SA_41": "Belastungsgewoehnng",
    "SA_65": "Verteidigungshaltung",
}

# Attribute abbreviation → canonical key
ATTR_MAP: dict[str, str] = {
    "AT": "at",
    "PA": "pa",
    "AW": "aw",
    "TP": "tp",
    "BE": "be",
    "INI": "ini",
    "GS": "gs",
    "FK": "fk",
}

# Scope inference based on attribute
DEFAULT_SCOPE: dict[str, str] = {
    "at": "meleeAttack",
    "pa": "meleeDefense",
    "aw": "meleeDefense",
    "tp": "meleeAttack",
    "be": "all",
    "ini": "combat",
    "gs": "all",
    "fk": "ranged",
}

# ---------------------------------------------------------------------------
# Hardcoded fallback — manually verified effects for critical combat SAs
# ---------------------------------------------------------------------------
HARDCODED_EFFECTS: list[dict] = [
    {
        "rule_id": "SA_48",
        "name": "Finte",
        "effects": [
            {
                "level": 1,
                "type": "modifier",
                "attribute": "at",
                "value": -1,
                "scope": "meleeAttack",
                "description": "Finte I: AT-1, Gegner PA-2",
            },
            {
                "level": 2,
                "type": "modifier",
                "attribute": "at",
                "value": -2,
                "scope": "meleeAttack",
                "description": "Finte II: AT-2, Gegner PA-4",
            },
            {
                "level": 3,
                "type": "modifier",
                "attribute": "at",
                "value": -3,
                "scope": "meleeAttack",
                "description": "Finte III: AT-3, Gegner PA-6",
            },
        ],
    },
    {
        "rule_id": "SA_67",
        "name": "Wuchtschlag",
        "effects": [
            {
                "level": 1,
                "type": "modifier",
                "attribute": "at",
                "value": -2,
                "scope": "meleeAttack",
                "description": "Wuchtschlag I: AT-2, TP+2",
            },
            {
                "level": 1,
                "type": "damageModifier",
                "attribute": "tp",
                "value": 2,
                "scope": "meleeAttack",
            },
            {
                "level": 2,
                "type": "modifier",
                "attribute": "at",
                "value": -4,
                "scope": "meleeAttack",
                "description": "Wuchtschlag II: AT-4, TP+4",
            },
            {
                "level": 2,
                "type": "damageModifier",
                "attribute": "tp",
                "value": 4,
                "scope": "meleeAttack",
            },
        ],
    },
    {
        "rule_id": "SA_66",
        "name": "Vorstoß",
        "effects": [
            {
                "type": "modifier",
                "attribute": "at",
                "value": 2,
                "scope": "meleeAttack",
                "description": "AT+2, keine Verteidigung möglich",
            },
            {
                "type": "restriction",
                "attribute": "defense",
                "scope": "meleeAttack",
            },
        ],
    },
    {
        "rule_id": "SA_65",
        "name": "Verteidigungshaltung",
        "effects": [
            {
                "type": "modifier",
                "attribute": "pa",
                "value": 4,
                "scope": "meleeDefense",
                "description": "PA+4, kein Angriff möglich",
            },
            {
                "type": "restriction",
                "attribute": "at",
                "scope": "combat",
            },
        ],
    },
    {
        "rule_id": "SA_41",
        "name": "Belastungsgewöhnung",
        "effects": [
            {
                "level": 1,
                "type": "modifier",
                "attribute": "be",
                "value": -1,
                "scope": "all",
            },
            {
                "level": 2,
                "type": "modifier",
                "attribute": "be",
                "value": -2,
                "scope": "all",
            },
        ],
    },
]


# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------

def fetch_page(url: str) -> BeautifulSoup:
    """Fetch and parse a wiki page with polite delay."""
    time.sleep(DELAY)
    resp = requests.get(url, headers=HEADERS, timeout=15)
    resp.raise_for_status()
    return BeautifulSoup(resp.text, "html.parser")


def discover_links(index_url: str) -> list[dict[str, str]]:
    """Discover individual rule page links from an index page.

    Returns a list of dicts with keys 'name' and 'url'.
    """
    soup = fetch_page(index_url)
    links: list[dict[str, str]] = []

    # Wiki index pages typically list rules as <a> links inside the main
    # content area.  We look for anchors whose href is a relative .html path.
    for a_tag in soup.select("a[href]"):
        href = a_tag["href"]
        if not href or href.startswith("#") or href.startswith("http"):
            continue
        # Skip navigation / non-rule links
        if href in ("index.html",):
            continue
        name = a_tag.get_text(strip=True)
        if name:
            full_url = f"{BASE_URL}/{href.lstrip('/')}"
            links.append({"name": name, "url": full_url})

    return links


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------

# Regex for numeric modifiers like "AT −2", "PA +1", "TP +2"
_MODIFIER_RE = re.compile(
    r"\b(AT|PA|AW|TP|BE|INI|GS|FK)\s*([+\u2212\u2013\-])\s*(\d+)"
)


def extract_modifiers(text: str) -> list[dict]:
    """Extract numeric modifiers from German rule text."""
    effects: list[dict] = []
    for match in _MODIFIER_RE.finditer(text):
        attr_raw = match.group(1)
        sign_char = match.group(2)
        magnitude = int(match.group(3))

        sign = -1 if sign_char in "\u2212\u2013-" else 1
        attr = ATTR_MAP.get(attr_raw, attr_raw.lower())
        scope = DEFAULT_SCOPE.get(attr, "combat")

        effect: dict = {
            "type": "damageModifier" if attr == "tp" and sign == 1 else "modifier",
            "attribute": attr,
            "value": sign * magnitude,
            "scope": scope,
        }
        effects.append(effect)

    return effects


def extract_level_effects(soup: BeautifulSoup) -> list[dict]:
    """Try to extract level-based effects from tables on the page."""
    effects: list[dict] = []

    # Look for tables that might contain level-based data
    for table in soup.find_all("table"):
        rows = table.find_all("tr")
        if len(rows) < 2:
            continue

        for row in rows[1:]:  # skip header
            cells = row.find_all(["td", "th"])
            if not cells:
                continue

            row_text = " ".join(c.get_text(" ", strip=True) for c in cells)
            mods = extract_modifiers(row_text)

            # Try to detect a level number in the first cell
            first_cell = cells[0].get_text(strip=True)
            level_match = re.match(r"(\d+)", first_cell)
            level = int(level_match.group(1)) if level_match else None

            for mod in mods:
                if level is not None:
                    mod["level"] = level
                effects.append(mod)

    return effects


def scrape_rule_page(url: str, rule_name: str) -> list[dict]:
    """Scrape a single rule page and extract effects."""
    try:
        soup = fetch_page(url)
    except requests.RequestException as exc:
        print(f"  [WARN] Failed to fetch {url}: {exc}", file=sys.stderr)
        return []

    # Gather all visible text
    main_content = soup.find("main") or soup.find("body") or soup
    full_text = main_content.get_text(" ", strip=True)

    # Try table-based extraction first (more structured)
    effects = extract_level_effects(soup)

    # Supplement with free-text extraction
    text_effects = extract_modifiers(full_text)

    # Merge: prefer table-based (they have level info), add text-only ones
    # that aren't duplicates
    existing = {(e["attribute"], e.get("value")) for e in effects}
    for te in text_effects:
        key = (te["attribute"], te.get("value"))
        if key not in existing:
            effects.append(te)
            existing.add(key)

    return effects


# ---------------------------------------------------------------------------
# Index page URLs to crawl
# ---------------------------------------------------------------------------
INDEX_PAGES: list[dict[str, str]] = [
    {
        "category": "Kampfsonderfertigkeiten",
        "url": f"{BASE_URL}/Kampfsonderfertigkeiten.html",
    },
]


# ---------------------------------------------------------------------------
# Main orchestration
# ---------------------------------------------------------------------------

def build_hardcoded_index() -> dict[str, dict]:
    """Index hardcoded effects by rule_id for quick lookup."""
    return {entry["rule_id"]: entry for entry in HARDCODED_EFFECTS}


def scrape_all(verbose: bool = False) -> list[dict]:
    """Scrape effects from wiki pages, falling back to hardcoded data."""
    hardcoded = build_hardcoded_index()
    results: dict[str, dict] = {}

    # ------------------------------------------------------------------
    # Phase 1: try scraping known rules directly
    # ------------------------------------------------------------------
    for rule_id, name in KNOWN_RULES.items():
        if verbose:
            print(f"Scraping {rule_id} ({name})...")

        # Try common URL patterns
        url_candidates = [
            f"{BASE_URL}/{name}.html",
            f"{BASE_URL}/{name.replace(' ', '_')}.html",
        ]

        effects: list[dict] = []
        for url in url_candidates:
            effects = scrape_rule_page(url, name)
            if effects:
                break

        if effects:
            results[rule_id] = {
                "rule_id": rule_id,
                "name": name,
                "effects": effects,
                "_source": "scraped",
            }
            if verbose:
                print(f"  Found {len(effects)} effects (scraped)")
        elif rule_id in hardcoded:
            results[rule_id] = dict(hardcoded[rule_id])
            results[rule_id]["_source"] = "hardcoded"
            if verbose:
                print(f"  Using hardcoded fallback")
        else:
            if verbose:
                print(f"  No effects found, no fallback available")

    # ------------------------------------------------------------------
    # Phase 2: discover additional rules from index pages
    # ------------------------------------------------------------------
    for idx_info in INDEX_PAGES:
        if verbose:
            print(f"\nDiscovering links from {idx_info['category']}...")

        try:
            links = discover_links(idx_info["url"])
        except requests.RequestException as exc:
            print(
                f"  [WARN] Could not fetch index {idx_info['url']}: {exc}",
                file=sys.stderr,
            )
            continue

        if verbose:
            print(f"  Found {len(links)} linked pages")

        for link in links:
            # Skip rules we already have
            if any(r["name"] == link["name"] for r in results.values()):
                continue

            effects = scrape_rule_page(link["url"], link["name"])
            if effects:
                # Generate a placeholder rule_id for discovered rules
                placeholder_id = f"SA_UNKNOWN_{link['name']}"
                results[placeholder_id] = {
                    "rule_id": placeholder_id,
                    "name": link["name"],
                    "effects": effects,
                    "_source": "scraped",
                    "_comment": "Auto-discovered; rule_id needs manual mapping",
                }
                if verbose:
                    print(f"  {link['name']}: {len(effects)} effects")

    # ------------------------------------------------------------------
    # Phase 3: ensure all hardcoded entries are present
    # ------------------------------------------------------------------
    for rule_id, entry in hardcoded.items():
        if rule_id not in results:
            results[rule_id] = dict(entry)
            results[rule_id]["_source"] = "hardcoded"

    return list(results.values())


def clean_for_output(entries: list[dict]) -> list[dict]:
    """Remove internal metadata keys before writing YAML."""
    cleaned = []
    for entry in entries:
        out = {k: v for k, v in entry.items() if not k.startswith("_")}
        cleaned.append(out)
    return cleaned


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Scrape DSA 5 rule effects from ulisses-regelwiki.de"
    )
    parser.add_argument(
        "--output",
        "-o",
        type=Path,
        default=Path("effects.yaml"),
        help="Output YAML file path (default: effects.yaml)",
    )
    parser.add_argument(
        "--hardcoded-only",
        action="store_true",
        help="Skip web scraping; emit only the hardcoded fallback data",
    )
    parser.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print progress to stderr",
    )
    args = parser.parse_args()

    if args.hardcoded_only:
        entries = HARDCODED_EFFECTS
        if args.verbose:
            print(
                f"Using hardcoded data only ({len(entries)} rules)",
                file=sys.stderr,
            )
    else:
        entries = scrape_all(verbose=args.verbose)

    output_data = clean_for_output(entries)

    yaml_str = yaml.dump(
        output_data,
        allow_unicode=True,
        default_flow_style=False,
        sort_keys=False,
    )

    args.output.write_text(yaml_str, encoding="utf-8")

    print(f"Wrote {len(output_data)} rules to {args.output}")

    # Summary
    sources = {}
    for entry in entries:
        src = entry.get("_source", "hardcoded")
        sources[src] = sources.get(src, 0) + 1
    for src, count in sorted(sources.items()):
        print(f"  {src}: {count}")


if __name__ == "__main__":
    main()
