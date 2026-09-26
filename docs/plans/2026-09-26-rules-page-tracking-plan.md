# Rule-Website Page Tracking Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers-extended-cc:subagent-driven-development (recommended) or superpowers-extended-cc:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tracked registry of every page of https://dsa.ulisses-regelwiki.de/ (`specs/rules/pages.yaml`) with a stable hash per page, so `make rules-coverage` can say how many pages are processed and which rule files to reprocess when a page changes.

**Architecture:** A new package `scripts/rules_sync/`. Three modules are ported from `origin/feat/rules-data-pipeline`: `normalise.py` (page HTML → stable text → `sha256:` hash), `check.py` (the cached, rate-limited fetcher and the rule-file side of the comparison) and `resolve.py` (index-page parsing, the crawl, name normalisation). Two new modules sit on top: `pages.py` (the `pages.yaml` model) and `sync.py`/`coverage.py` (the two commands). Status per page is derived at report time from `pages.yaml` plus the rule files' `source` blocks; it is never stored.

**Tech Stack:** Python 3.11+, `requests`, `beautifulsoup4`, `pyyaml`, run through `uv run --with …` like `rulec`; `unittest` like every other script in this repo.

**Spec:** memory note `rules-page-tracking-plan` (owner decision, 2026-09-26). Its content is restated under *User decisions* below, so this plan stands alone.

## Global Constraints

- **Never guess a URL.** Every URL in `pages.yaml` is an `href` the site publishes, joined against the page's `<base href>`, fragment removed, otherwise byte for byte (percent-encoding kept). This is `resolve.py`'s rule and it stays.
- **Politeness:** one real network request per second at most (`DELAY = 1.0`), `User-Agent: DSA-Companion-Scraper/1.0`, disk cache under `.cache/rules_sync/` (git-ignored). Tests never touch the network.
- **Hash format:** `sha256:<64 hex>` of `normalise_html(html)`, exactly as the ported `hash_html` computes it. `normalise.py` is ported unchanged; its tests are the contract.
- **`pages.yaml` is written only by `make rules-sync`**, except the `skip` fields, which a person edits. A sync keeps every `skip` it finds.
- **Rule files are written only through `scripts/rules_review/rulefiles.py`** (its checked, line-surgical edits). `rules-sync` never touches a rule file unless `ADOPT` is given.
- **Tests are `unittest`**, next to the code (`scripts/rules_sync/test_*.py`), fixtures in `scripts/rules_sync/fixtures/`. Fixtures are invented markup, not captures of real pages.
- **Imports:** the package runs from `scripts/` (`cd scripts && … python -m rules_sync …`), so imports read `from rules_sync.normalise import …`, never `from scripts.rules_sync…`.
- **Do not port** `propose.py`, `rule_graph.py`, the calibration workspace, the leak guards, the Optolith/`rules.db` identity confirmation (`confirm_identity`, `load_targets`, `RuleTarget`, `write_map`) or `test_normalise_live.py`. The owner ruled these out (failed gate).

**User decisions (already made):**
- Scope is every rule category of the site, crawled from its index pages — not only combat, not only Optolith ids. Out-of-scope pages get `skip` with a reason.
- Stored per page: url, title, hash, fetched, skip. Status is derived: new / skipped / drafted / reviewed / changed (page hash ≠ rule file's `source.hash`).
- Port `normalise.py`, `check.py`, `resolve.py` from `origin/feat/rules-data-pipeline`; not its agent pipeline, calibration or leak guards.
- Targets: `make rules-sync` (refetch + hash) and `make rules-coverage` (counts per status).

**Choices this plan makes (the owner can overturn each before Task 1 starts):**
1. **`rules` is not stored in `pages.yaml`.** The memory note lists it, but the rule files' `source.url` already says which page each rule comes from. Storing it again gives two records that can disagree. `rules-coverage` derives page → rule ids from the rule files.
2. **`fetched` is the date the stored hash was first seen**, not the date of the last fetch. Otherwise every sync rewrites every line, and the diff hides the pages that really changed. A top-level `synced:` records the last run.
3. **Category skips.** Besides a per-page `skip`, a top-level `skip:` map keyed by an index trail prefix (for example `Bestiarium` or `Magie / Zaubersprüche`) skips a whole subtree with one reason.
4. **Hash baseline (`ADOPT`).** All rule files have `source.hash: null` today. `make rules-sync ADOPT=1` writes the current page hash (and today's `checked`) into every rule file whose hash is null. `ADOPT=SA_40,ADV_4` re-adopts named rules after they were reprocessed. Until adoption a rule counts as `unhashed`, not `changed`.
5. **Index pages are recorded** with `kind: index` and no hash, so the crawl's shape is visible, but they are not counted as rule pages.

---

## File Structure

| File | Responsibility |
|---|---|
| `scripts/rules_sync/__init__.py` | package marker |
| `scripts/rules_sync/__main__.py` | `python -m rules_sync sync|coverage` dispatch |
| `scripts/rules_sync/normalise.py` | ported unchanged: HTML → text → hash |
| `scripts/rules_sync/check.py` | ported and cut down: `Fetcher` (cache with max age), `rule_sources()` (rule files → url, hash, reviewed) |
| `scripts/rules_sync/resolve.py` | ported and cut down: `index_anchors`, `page_base`, `page_title`, `classify_page`, `normalise_name`, `candidates`, `root_categories`, `crawl` (site-wide, records the trail) |
| `scripts/rules_sync/pages.py` | `pages.yaml` load, merge with a crawl, deterministic dump, skip lookup |
| `scripts/rules_sync/sync.py` | `make rules-sync`: crawl → hash → merge → write; `--adopt` |
| `scripts/rules_sync/coverage.py` | `make rules-coverage`: derive status, print counts and lists |
| `scripts/rules_sync/fixtures/*.html` | invented markup for tests |
| `scripts/rules_sync/test_*.py` | unit tests |
| `scripts/rules_review/rulefiles.py` | add `set_source_hash` |
| `scripts/rulec/layout.py` | add `pages.yaml` to `NOT_RULES` |
| `specs/rules/pages.yaml` | the registry (generated) |
| `Makefile`, `.gitignore`, `AGENTS.md`, `specs/rules/README.md`, `CHANGELOG.md` | wiring and docs |

---

### Task 1: Package scaffold and `normalise.py` port

**Goal:** `scripts/rules_sync/` exists with `normalise.py` ported unchanged and its tests passing under `make test-rules-sync`.

**Files:**
- Create: `scripts/rules_sync/__init__.py`, `scripts/rules_sync/normalise.py`, `scripts/rules_sync/test_normalise.py`, `scripts/rules_sync/fixtures/rule_a.html`, `rule_b.html`, `rule_c_different.html`, `rule_d_dynamic1.html`, `rule_d_dynamic2.html` (plus any other fixture `test_normalise.py` reads)
- Modify: `Makefile` (add `RULES_SYNC` and `test-rules-sync`), `.gitignore` (add `.cache/`), `scripts/rulec/layout.py` (add `PAGES = "pages.yaml"` to `NOT_RULES`)

**Acceptance Criteria:**
- [ ] `normalise.py` is byte-identical to the branch file except the module docstring's references to the branch's task reports, which are replaced by one line: `Ported from feat/rules-data-pipeline (see its Task 5 report for the live-site evidence).`
- [ ] Every test in the branch's `tests/rules/test_normalise.py` exists as a `unittest` method with the same name and the same assertion.
- [ ] `make test-rules-sync` passes.
- [ ] `pages.yaml` is in `layout.NOT_RULES` (Task 4's tests assert that `rule_files()` leaves it out).

**Verify:** `make test-rules-sync` → `OK`

**Steps:**

- [ ] **Step 1: Copy the module and fixtures from the branch**

```bash
B=origin/feat/rules-data-pipeline
mkdir -p scripts/rules_sync/fixtures
git show "${B}:scripts/rules_sync/normalise.py" > scripts/rules_sync/normalise.py
for f in $(git ls-tree --name-only "${B}" tests/rules/fixtures/); do
  git show "${B}:$f" > "scripts/rules_sync/fixtures/$(basename "$f")"
done
touch scripts/rules_sync/__init__.py
```

All fixtures are copied now; Task 3 uses the `index_*.html` ones.

- [ ] **Step 2: Convert `test_normalise.py` to unittest**

`git show "${B}:tests/rules/test_normalise.py"` and rewrite it as `scripts/rules_sync/test_normalise.py`:

```python
"""normalise.py: two captures of the same text hash the same; different text does not.

    make test-rules-sync
"""
import pathlib
import unittest

from rules_sync.normalise import (
    ContentContainerEmpty,
    ContentContainerError,
    ContentContainerNotFound,
    hash_html,
    normalise_html,
)

FIXTURES = pathlib.Path(__file__).parent / "fixtures"


def _read(name):
    return (FIXTURES / name).read_text(encoding="utf-8")


class NormaliseTests(unittest.TestCase):
    def test_differently_marked_up_captures_normalise_to_the_same_text(self):
        self.assertEqual(normalise_html(_read("rule_a.html")), normalise_html(_read("rule_b.html")))

    def test_hash_has_the_sha256_prefix_form(self):
        h = hash_html(_read("rule_a.html"))
        self.assertTrue(h.startswith("sha256:"))
        self.assertEqual(len(h), len("sha256:") + 64)

    # … every other branch test, one method each: `assert x == y` → assertEqual,
    # `with pytest.raises(E):` → `with self.assertRaises(E):`,
    # `@pytest.mark.parametrize` → a loop with `with self.subTest(case=…):`.
```

Keep the branch file's module docstring text about the fixtures (it explains them); drop the `pytest` import.

- [ ] **Step 3: Makefile, .gitignore, layout**

Append after the `rules-json` target in `Makefile`:

```make
# Rule-website page tracking (docs/plans/2026-09-26-rules-page-tracking-plan.md).
RULES_SYNC = cd scripts && uv run --with requests --with beautifulsoup4 --with pyyaml python

test-rules-sync:
	$(RULES_SYNC) -m unittest discover -s rules_sync -t . -p 'test_*.py' -v
```

`.gitignore`: add a line `.cache/`.

`scripts/rulec/layout.py`:

```python
PAGES = "pages.yaml"

# Entries of the root that are not rule files.
NOT_RULES = {SITUATIONS, SWEEPS, CHECKS, SHARED_RULINGS, PAGES}
```

- [ ] **Step 4: Run** `make test-rules-sync` → `OK`. Also run `make test-rulec` and `make test-rules-review` → both still `OK`.

- [ ] **Step 5: Commit**

```bash
git add scripts/rules_sync Makefile .gitignore scripts/rulec/layout.py
git commit -m "feat(rules): port the page normaliser from the data-pipeline branch"
```

---

### Task 2: `check.py` port — fetcher with max age, rule-file sources

**Goal:** A `Fetcher` that can refetch (cache entries older than `max_age` are fetched again) and a `rule_sources()` that reads every rule file's `source` block.

**Files:**
- Create: `scripts/rules_sync/check.py`, `scripts/rules_sync/test_check.py`

**Acceptance Criteria:**
- [ ] `Fetcher(cache_dir, session, max_age=None)`: `max_age=None` means any cached copy is used (the branch behaviour); `max_age=timedelta(0)` means every URL is fetched again; a cached copy younger than `max_age` makes no network call and does not sleep.
- [ ] `Fetcher.network_calls` counts real fetches only.
- [ ] `rule_sources(root)` returns one `RuleSource(rule_id, path, url, hash, reviewed)` per rule file that has `source.url`, and also one per `source.also` entry that has a `url`. Files without a URL are left out. `url` is normalised by `canonical_url()` (join against `BASE_URL`, drop the fragment).
- [ ] The branch's `UNVERIFIED_*` placeholder logic, `NON_RULE_FILES`, `check_rule`, `run` and `main` are not ported (the rule layout and `pages.yaml` replace them).
- [ ] The branch's `Fetcher` tests are ported as unittest and pass.

**Verify:** `make test-rules-sync` → `OK`

**Steps:**

- [ ] **Step 1: Write the failing tests** (`scripts/rules_sync/test_check.py`)

```python
"""check.py: the fetcher's cache and max age; the rule files' sources."""
import datetime
import os
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

from rules_sync import check


class FakeResponse:
    def __init__(self, text):
        self.text = text

    def raise_for_status(self):
        pass


class FakeSession:
    def __init__(self):
        self.calls = []

    def get(self, url, headers=None, timeout=None):
        self.calls.append(url)
        return FakeResponse(f"<html>{url}</html>")


class FetcherTests(unittest.TestCase):
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.session = FakeSession()
        patcher = mock.patch.object(check.time, "sleep")
        self.sleep = patcher.start()
        self.addCleanup(patcher.stop)

    def test_a_warm_cache_makes_no_call_without_max_age(self):
        check.Fetcher(self.dir, self.session).get("https://x/a.html")
        f = check.Fetcher(self.dir, self.session)
        f.get("https://x/a.html")
        self.assertEqual(f.network_calls, 0)
        self.assertEqual(len(self.session.calls), 1)

    def test_max_age_zero_fetches_again(self):
        check.Fetcher(self.dir, self.session).get("https://x/a.html")
        f = check.Fetcher(self.dir, self.session, max_age=datetime.timedelta(0))
        f.get("https://x/a.html")
        self.assertEqual(f.network_calls, 1)

    def test_a_young_copy_is_used_an_old_one_is_not(self):
        f = check.Fetcher(self.dir, self.session, max_age=datetime.timedelta(hours=20))
        f.get("https://x/a.html")
        f.get("https://x/b.html")
        old = time.time() - 21 * 3600
        os.utime(f._cache_path("https://x/b.html"), (old, old))
        f2 = check.Fetcher(self.dir, self.session, max_age=datetime.timedelta(hours=20))
        f2.get("https://x/a.html")
        f2.get("https://x/b.html")
        self.assertEqual(f2.network_calls, 1)

    def test_a_real_fetch_sleeps_a_cache_hit_does_not(self):
        f = check.Fetcher(self.dir, self.session)
        f.get("https://x/a.html")
        f.get("https://x/a.html")
        self.assertEqual(self.sleep.call_count, 1)


RULE = """\
id: SA_1
name: Beispiel
kind: specialAbility
source:
  url: https://dsa.ulisses-regelwiki.de/KSF_Beispiel.html#top
  checked: 2026-09-24
  also:
    - { book: Irgendwas, page: 3 }
    - { url: https://dsa.ulisses-regelwiki.de/KSF_Zweit.html }
  hash: sha256:abc
reviewed: { by: "@x", date: 2026-09-25 }
clauses: []
"""


class RuleSourceTests(unittest.TestCase):
    def test_reads_url_also_url_hash_and_reviewed(self):
        root = Path(tempfile.mkdtemp())
        (root / "abilities").mkdir()
        (root / "abilities" / "SA_1.yaml").write_text(RULE, encoding="utf-8")
        (root / "abilities" / "SA_2.yaml").write_text("id: SA_2\nclauses: []\n", encoding="utf-8")
        got = check.rule_sources(root)
        self.assertEqual([(s.rule_id, s.url, s.hash) for s in got], [
            ("SA_1", "https://dsa.ulisses-regelwiki.de/KSF_Beispiel.html", "sha256:abc"),
            ("SA_1", "https://dsa.ulisses-regelwiki.de/KSF_Zweit.html", "sha256:abc"),
        ])
        self.assertTrue(got[0].reviewed)

    def test_canonical_url_joins_and_drops_the_fragment(self):
        self.assertEqual(check.canonical_url("KSF_Vorsto%C3%9F.html#x"),
                         "https://dsa.ulisses-regelwiki.de/KSF_Vorsto%C3%9F.html")
```

Also port each branch `Fetcher` test from `tests/rules/test_check.py` that is not already covered above. Skip the branch tests of `check_rule`/`run`/`UNVERIFIED`.

- [ ] **Step 2: Run** `make test-rules-sync` → FAIL (`module 'rules_sync.check' has no attribute …`).

- [ ] **Step 3: Write `check.py`**

Start from `git show origin/feat/rules-data-pipeline:scripts/rules_sync/check.py`. Keep the module's politeness comment, `DELAY`, `HEADERS`, `CACHE_DIR` and the `Fetcher` class. Replace the rest:

```python
"""The fetch side of page tracking, and what the rule files say about their pages.

Ported from feat/rules-data-pipeline. `Fetcher` is its disk-cached, rate-limited GET, plus a
`max_age`: `make rules-sync` has to see today's page, so a copy older than that is fetched
again, while a run that stopped half-way resumes from the copies it already made.
"""
from __future__ import annotations

import datetime
import hashlib
import time
from pathlib import Path
from typing import NamedTuple
from urllib.parse import urljoin

import requests
import yaml

from rulec import layout

REPO_ROOT = Path(__file__).resolve().parents[2]
CACHE_DIR = REPO_ROOT / ".cache" / "rules_sync"
BASE_URL = "https://dsa.ulisses-regelwiki.de/"

DELAY = 1.0
HEADERS = {"User-Agent": "DSA-Companion-Scraper/1.0"}


def canonical_url(url: str) -> str:
    """`url` joined against the site root, fragment dropped, otherwise unchanged."""
    return urljoin(BASE_URL, url.strip()).partition("#")[0]


class Fetcher:
    """Disk-cached, rate-limited HTTP GET. (keep the branch docstring, add the max_age paragraph)"""

    def __init__(self, cache_dir: Path = CACHE_DIR, session=None, max_age: "datetime.timedelta | None" = None):
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(parents=True, exist_ok=True)
        self.session = session or requests.Session()
        self.max_age = max_age
        self.network_calls = 0

    def _cache_path(self, url: str) -> Path:
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()
        return self.cache_dir / f"{digest}.html"

    def _fresh(self, path: Path) -> bool:
        if not path.exists():
            return False
        if self.max_age is None:
            return True
        return time.time() - path.stat().st_mtime < self.max_age.total_seconds()

    def get(self, url: str) -> str:
        cache_path = self._cache_path(url)
        if self._fresh(cache_path):
            return cache_path.read_text(encoding="utf-8")
        time.sleep(DELAY)
        response = self.session.get(url, headers=HEADERS, timeout=15)
        response.raise_for_status()
        self.network_calls += 1
        cache_path.write_text(response.text, encoding="utf-8")
        return response.text


class RuleSource(NamedTuple):
    rule_id: str
    path: Path
    url: str
    hash: "str | None"
    reviewed: bool


def rule_sources(root: Path = layout.ROOT) -> list[RuleSource]:
    """One entry per page a rule file names: `source.url`, and any `source.also[].url`."""
    out = []
    for path in layout.rule_files(root):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        if not isinstance(doc, dict):
            continue
        source = doc.get("source") or {}
        urls = [source.get("url")] + [a.get("url") for a in source.get("also") or [] if isinstance(a, dict)]
        for url in filter(None, urls):
            out.append(RuleSource(str(doc.get("id", path.stem)), path, canonical_url(str(url)),
                                  source.get("hash"), bool(doc.get("reviewed"))))
    return out
```

`from rulec import layout` works because the package runs from `scripts/`. `layout.rule_files(root)` with a temp root works as the test needs (it only globs `root`).

- [ ] **Step 4: Run** `make test-rules-sync` → `OK`

- [ ] **Step 5: Commit** `git commit -m "feat(rules): port the cached fetcher; read each rule file's source pages"`

---

### Task 3: `resolve.py` port — site-wide crawl with trails

**Goal:** A crawl that starts at the site root's top menu, walks every index subtree, and returns every page it reached with its kind, title, hash and index trail.

**Files:**
- Create: `scripts/rules_sync/resolve.py`, `scripts/rules_sync/test_resolve.py`, `scripts/rules_sync/fixtures/site_root.html`
- Use: the ported `fixtures/index_*.html`, `rule_*.html`

**Acceptance Criteria:**
- [ ] Ported unchanged (bodies and docstrings): `index_anchors`, `page_base`, `page_title`, `classify_page`, `_fold`, `normalise_name` and the regexes they use, `INDEX_ANCHOR_SELECTOR`, `Problem`, `_same_site`.
- [ ] New `root_categories(html, url) -> list[tuple[str, str]]` reads `ul.sf-menu.level_1 > li > a` (anchor text, absolute URL), same-site `.html` links only, in document order. A root with no such menu raises `LookupError` naming the selector.
- [ ] New `crawl(fetcher, root_url=BASE_URL, max_depth=6, max_pages=20000) -> SiteCrawl`. `SiteCrawl.pages` is a dict `url -> CrawledPage(url, kind, title, hash, trail, detail)`, `kind` in `rule | index | broken`; `trail` is the anchor texts from the top category down to the page, first path found breadth-first; `SiteCrawl.problems` is a list of `Problem`.
- [ ] A rule page's `hash` is `hash_html(html)`; an index or broken page has `hash=None`; a broken page has the `classify_page` reason as `detail`.
- [ ] A fetch failure, a truncated crawl (`max_pages`) and a depth stop are fatal `Problem`s (the branch's reasoning, kept as comments); a broken page is a non-fatal one.
- [ ] `candidates(name, titles) -> list[str]` returns up to `CANDIDATE_COUNT` titles whose `normalise_name` is within `CANDIDATE_CUTOFF` by `difflib.get_close_matches` (the branch's `_candidates_for` idea, over page titles).
- [ ] Not ported: `GROUP_INDEX_TRAIL`, `follow_trail`, `COMBAT_GROUPS`, identity signals, publications, `RuleTarget`, `Resolution`, `load_targets`, `render_report`, `write_map`, `run`, `main`, any `sqlite3` use.
- [ ] The branch tests of the ported functions pass as unittest; new tests cover `root_categories` and `crawl`.

**Verify:** `make test-rules-sync` → `OK`

**Steps:**

- [ ] **Step 1: Fixture for the root.** `scripts/rules_sync/fixtures/site_root.html`, invented markup with the site's real shape:

```html
<!DOCTYPE html>
<html><head><base href="https://dsa.ulisses-regelwiki.de/"><title>Start - DSA Regel-Wiki</title></head>
<body>
<div class="t4c_main_nav"><nav class="mod_t4c_megamenu block">
  <ul class="sf-menu level_1">
    <li class="sibling first"><a href="kat_eins.html" class="ulsubmenu sibling first">Kategorie Eins</a></li>
    <li class="sibling"><a href="kat_zwei.html" class="sibling">Kategorie Zwei</a></li>
    <li><a href="//ulisses-regelwiki.de/kontakt.html">Kontakt</a></li>
  </ul>
</nav></div>
<div id="main"><p>Willkommen im Platzhalter-Wiki.</p></div>
</body></html>
```

- [ ] **Step 2: Failing tests** (`scripts/rules_sync/test_resolve.py`)

Port every branch test from `tests/rules/test_resolve.py` that exercises a function kept above (`index_anchors`, `page_base`, `page_title`, `classify_page`, `normalise_name`) as unittest methods. Add:

```python
class FakeFetcher:
    """Serves a dict of url -> html; anything else raises like requests would."""
    def __init__(self, pages):
        self.pages = pages
        self.network_calls = 0

    def get(self, url):
        if url not in self.pages:
            raise requests.HTTPError(f"404 {url}")
        return self.pages[url]


BASE = "https://dsa.ulisses-regelwiki.de/"


def _index(links, main=""):
    anchors = "".join(f'<a class="ulSubMenu" href="{h}">{t}</a>' for t, h in links)
    return (f'<html><head><base href="{BASE}"></head><body>'
            f'<div id="sub_header"><nav class="mod_navigation">{anchors}</nav></div>'
            f'<div id="main">{main}</div></body></html>')


def _rule(title, text):
    return (f'<html><head><base href="{BASE}"><title>{title} - DSA Regel-Wiki</title></head>'
            f'<body><div id="main"><h1>{title}</h1><p>{text}</p></div></body></html>')


class RootCategoryTests(unittest.TestCase):
    def test_reads_the_top_menu_same_site_only(self):
        html = (FIXTURES / "site_root.html").read_text(encoding="utf-8")
        self.assertEqual(resolve.root_categories(html, BASE), [
            ("Kategorie Eins", BASE + "kat_eins.html"),
            ("Kategorie Zwei", BASE + "kat_zwei.html"),
        ])

    def test_no_menu_is_an_error(self):
        with self.assertRaises(LookupError):
            resolve.root_categories("<html><body></body></html>", BASE)


class CrawlTests(unittest.TestCase):
    def site(self):
        root = (FIXTURES / "site_root.html").read_text(encoding="utf-8")
        return {
            BASE: root,
            BASE + "kat_eins.html": _index([("Unter", "unter.html"), ("Regel A", "a.html")]),
            BASE + "unter.html": _index([("Regel B", "b.html"), ("Regel A", "a.html")]),
            BASE + "a.html": _rule("Regel A", "Text A"),
            BASE + "b.html": _rule("Regel B", "Text B"),
            BASE + "kat_zwei.html": _index([("Leer", "leer.html")]),
            BASE + "leer.html": '<html><body><div id="main"></div></body></html>',
        }

    def test_every_page_with_kind_trail_and_hash(self):
        got = resolve.crawl(FakeFetcher(self.site()))
        a = got.pages[BASE + "a.html"]
        self.assertEqual((a.kind, a.title, a.trail), ("rule", "Regel A", ("Kategorie Eins", "Regel A")))
        self.assertTrue(a.hash.startswith("sha256:"))
        self.assertEqual(got.pages[BASE + "b.html"].trail, ("Kategorie Eins", "Unter", "Regel B"))
        self.assertEqual(got.pages[BASE + "kat_eins.html"].kind, "index")
        self.assertIsNone(got.pages[BASE + "kat_eins.html"].hash)
        self.assertEqual(got.pages[BASE + "leer.html"].kind, "broken")
        self.assertFalse([p for p in got.problems if p.fatal])

    def test_a_missing_page_is_fatal(self):
        site = self.site()
        del site[BASE + "unter.html"]
        got = resolve.crawl(FakeFetcher(site))
        self.assertTrue(any(p.fatal and "unter.html" in p.detail for p in got.problems))

    def test_max_pages_is_fatal(self):
        got = resolve.crawl(FakeFetcher(self.site()), max_pages=3)
        self.assertTrue(any(p.fatal and "stopped" in p.detail for p in got.problems))


class CandidateTests(unittest.TestCase):
    def test_near_titles_are_offered(self):
        self.assertEqual(resolve.candidates("Wuchtschlag", ["Wuchtschlag I-III", "Finte"]),
                         ["Wuchtschlag I-III"])
```

The root page itself is not stored in `pages` (it is the entry point, not a category page). Index pages under it are stored with `kind: index`.

- [ ] **Step 3: Run** → FAIL.

- [ ] **Step 4: Write `resolve.py`**

Copy the kept functions from `git show origin/feat/rules-data-pipeline:scripts/rules_sync/resolve.py` with their docstrings and comments. Replace the module docstring with a short one: what is kept, what is dropped and why (the owner's ruling), and the "never guess a URL" section verbatim. Change the imports to `from rules_sync.check import BASE_URL, canonical_url` and `from rules_sync.normalise import ContentContainerEmpty, ContentContainerNotFound, hash_html, normalise_html`. New code:

```python
ROOT_MENU_SELECTOR = "ul.sf-menu.level_1 > li > a"
MAX_DEPTH = 6        # the deepest trail seen on 2026-09-26 is 4 below a top category
MAX_PAGES = 20000    # a stop against a redesign or a cycle, far above the site's size


@dataclass(frozen=True)
class CrawledPage:
    url: str
    kind: str                 # rule | index | broken
    title: str
    hash: "str | None"
    trail: tuple[str, ...]
    detail: str = ""


@dataclass
class SiteCrawl:
    pages: dict[str, CrawledPage] = field(default_factory=dict)
    problems: list[Problem] = field(default_factory=list)

    @property
    def fatal_problems(self) -> list[Problem]:
        return [p for p in self.problems if p.fatal]


def root_categories(html: str, url: str) -> list[tuple[str, str]]:
    """The top categories the site root's menu lists, as (anchor text, absolute URL)."""
    soup = BeautifulSoup(html, "html.parser")
    anchors = soup.select(ROOT_MENU_SELECTOR)
    if not anchors:
        raise LookupError(f"{url}: no top menu ({ROOT_MENU_SELECTOR}) -- the site's markup changed")
    base = page_base(html, url)
    out = []
    for a in anchors:
        text, href = a.get_text(strip=True), (a.get("href") or "").strip()
        child = canonical_url(urljoin(base, href))
        if text and href and _same_site(child, url) and child.endswith(".html") and (text, child) not in out:
            out.append((text, child))
    return out


def crawl(fetcher, root_url: str = BASE_URL, *, max_depth: int = MAX_DEPTH,
          max_pages: int = MAX_PAGES) -> SiteCrawl:
    """Breadth-first walk from the root menu's categories through every index page.

    Kept from the branch: an index is a page with `a.ulSubMenu` anchors; its anchors are
    enqueued; a fetch failure, a depth stop and a page cap are fatal because every page behind
    them is missing with no sign of it; a page with no text and no anchors is noted, not fatal.
    New: every page reached is returned, index pages included, each with the trail of anchor
    texts by which it was first reached.
    """
    result = SiteCrawl()
    root_html = fetcher.get(root_url)
    queue = [(url, 0, (text,)) for text, url in root_categories(root_html, root_url)]
    seen = {url for url, _, _ in queue}
    while queue:
        url, depth, trail = queue.pop(0)
        if len(result.pages) >= max_pages:
            result.problems.append(Problem(True, f"crawl stopped at {max_pages} pages -- look at the site"))
            break
        try:
            html = fetcher.get(url)
        except requests.RequestException as exc:
            result.problems.append(Problem(True, f"{url}: fetch failed: {exc}"))
            continue
        kind, detail = classify_page(html)
        if kind == "broken":
            result.problems.append(Problem(False, f"{url}: {detail}"))
            result.pages[url] = CrawledPage(url, "broken", page_title(html), None, trail, detail)
            continue
        if kind == "rule":
            result.pages[url] = CrawledPage(url, "rule", page_title(html), hash_html(html), trail)
            continue
        result.pages[url] = CrawledPage(url, "index", page_title(html), None, trail)
        if depth >= max_depth:
            result.problems.append(Problem(True, f"{url}: max depth {max_depth} reached, not descending"))
            continue
        base = page_base(html, url)
        for text, href in index_anchors(html):
            child = canonical_url(urljoin(base, href))
            if not _same_site(child, root_url) or child in seen:
                continue
            seen.add(child)
            queue.append((child, depth + 1, trail + (text,)))
    return result


def candidates(name: str, titles) -> list[str]:
    """Near-miss page titles for a name, for a person to look at. Never a resolution."""
    by_key = {}
    for t in titles:
        by_key.setdefault(normalise_name(t), t)
    keys = difflib.get_close_matches(normalise_name(name), list(by_key), n=CANDIDATE_COUNT, cutoff=CANDIDATE_CUTOFF)
    return [by_key[k] for k in keys]
```

`classify_page` calls `normalise_html`, and `crawl` calls `hash_html` on the same HTML for a rule page; that normalises twice. Accept it (the fetch dominates by orders of magnitude).

- [ ] **Step 5: Run** `make test-rules-sync` → `OK`

- [ ] **Step 6: Commit** `git commit -m "feat(rules): port the index crawler and walk the whole rule website"`

---

### Task 4: `pages.py` — the `pages.yaml` model

**Goal:** Load, merge and write `specs/rules/pages.yaml` deterministically, keeping every hand-written `skip`.

**Files:**
- Create: `scripts/rules_sync/pages.py`, `scripts/rules_sync/test_pages.py`

**Acceptance Criteria:**
- [ ] File format, exactly:

```yaml
# Every page of https://dsa.ulisses-regelwiki.de/, written by `make rules-sync`.
# Edit only `skip` (here, or on a page). Status is derived: `make rules-coverage`.
synced: 2026-09-26
skip:
  Wege der Vereinigungen - ab 18 Jahre: not part of the app
pages:
  KSF_Aufmerksamkeit.html: {title: Aufmerksamkeit, in: Sonderfertigkeiten / Profane Sonderfertigkeiten / Kampfsonderfertigkeiten, kind: rule, hash: 'sha256:…', fetched: 2026-09-26}
  frefre.html: {title: Profane Sonderfertigkeiten, in: Sonderfertigkeiten / Profane Sonderfertigkeiten, kind: index}
```

  Keys are URLs relative to `BASE_URL`, sorted by `str`. Fields in the order `title, in, kind, hash, fetched, skip, gone, detail`; absent ones are left out. One page per line.
- [ ] `merge(old: Registry, crawl: SiteCrawl, today) -> Registry`:
  - a page whose hash is unchanged keeps its old `fetched`; a new or changed hash gets `fetched: today`;
  - a page in `old` but not in the crawl keeps its entry and gets `gone: <today>` (an existing `gone` date is kept);
  - a page that comes back loses `gone`;
  - every `skip` (page and top-level) is kept;
  - `synced` becomes `today`.
- [ ] `merge` refuses (raises `ValueError`) when the crawl has a fatal problem, so a partial crawl never marks half the site `gone`.
- [ ] `Registry.skip_reason(key) -> str | None`: the page's own `skip`, else the reason of the longest top-level `skip` key that is a prefix of the page's trail (`"A / B"` matches trail `A / B / C`, not `A / Bx`).
- [ ] `dump(load(text)) == text` for a written file (round trip).
- [ ] `layout.rule_files(layout.ROOT)` does not contain `pages.yaml` (asserted here).

**Verify:** `make test-rules-sync` → `OK`

**Steps:**

- [ ] **Step 1: Failing tests** (`scripts/rules_sync/test_pages.py`)

```python
"""pages.py: merge keeps skips and dates; the file round-trips."""
import datetime
import unittest

from rulec import layout
from rules_sync import pages
from rules_sync.resolve import CrawledPage, Problem, SiteCrawl

B = "https://dsa.ulisses-regelwiki.de/"
D1, D2 = datetime.date(2026, 9, 26), datetime.date(2026, 10, 3)


def crawl(*items, problems=()):
    c = SiteCrawl()
    for key, kind, h, trail in items:
        c.pages[B + key] = CrawledPage(B + key, kind, key.split(".")[0], h, tuple(trail.split(" / ")))
    c.problems.extend(problems)
    return c


class MergeTests(unittest.TestCase):
    def test_fetched_moves_only_when_the_hash_changes(self):
        r1 = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "K / a"),
                                                  ("b.html", "rule", "sha256:2", "K / b")), D1)
        r2 = pages.merge(r1, crawl(("a.html", "rule", "sha256:1", "K / a"),
                                   ("b.html", "rule", "sha256:9", "K / b")), D2)
        self.assertEqual(r2.pages["a.html"]["fetched"], D1)
        self.assertEqual(r2.pages["b.html"]["fetched"], D2)
        self.assertEqual(r2.synced, D2)

    def test_a_missing_page_is_gone_and_comes_back(self):
        r1 = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "K / a")), D1)
        r2 = pages.merge(r1, crawl(), D2)
        self.assertEqual(r2.pages["a.html"]["gone"], D2)
        r3 = pages.merge(r2, crawl(("a.html", "rule", "sha256:1", "K / a")), D2)
        self.assertNotIn("gone", r3.pages["a.html"])

    def test_skips_survive(self):
        r1 = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "K / a")), D1)
        r1.pages["a.html"]["skip"] = "not a rule"
        r1.skip["K"] = "whole category"
        r2 = pages.merge(r1, crawl(("a.html", "rule", "sha256:1", "K / a")), D2)
        self.assertEqual(r2.pages["a.html"]["skip"], "not a rule")
        self.assertEqual(r2.skip, {"K": "whole category"})

    def test_a_fatal_crawl_is_refused(self):
        with self.assertRaises(ValueError):
            pages.merge(pages.Registry(), crawl(problems=[Problem(True, "x: fetch failed")]), D1)


class SkipTests(unittest.TestCase):
    def test_page_skip_then_longest_trail_prefix(self):
        r = pages.merge(pages.Registry(), crawl(("a.html", "rule", "sha256:1", "A / B / a"),
                                                ("c.html", "rule", "sha256:3", "A / Bx / c")), D1)
        r.skip.update({"A": "outer", "A / B": "inner"})
        self.assertEqual(r.skip_reason("a.html"), "inner")
        self.assertEqual(r.skip_reason("c.html"), "outer")
        r.pages["a.html"]["skip"] = "own"
        self.assertEqual(r.skip_reason("a.html"), "own")


class FileTests(unittest.TestCase):
    def test_round_trip_and_one_line_per_page(self):
        r = pages.merge(pages.Registry(), crawl(("b.html", "rule", "sha256:2", "K: x / b"),
                                                ("a.html", "index", None, "K: x")), D1)
        r.skip["K: x"] = "a reason: with a colon"
        text = pages.dump(r)
        self.assertEqual(pages.dump(pages.load(text)), text)
        body = text.split("pages:\n", 1)[1].splitlines()
        self.assertEqual([l.split(":")[0].strip() for l in body], ["a.html", "b.html"])

    def test_pages_yaml_is_not_a_rule_file(self):
        self.assertNotIn(layout.ROOT / "pages.yaml", layout.rule_files(layout.ROOT))
```

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Write `pages.py`**

```python
"""specs/rules/pages.yaml: every page of the rule website, its hash, and what is skipped.

`make rules-sync` writes it; a person edits only `skip`. Nothing here decides a page's status:
that is derived from this file and the rule files, by `coverage.py`.
"""
from __future__ import annotations

import datetime
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from rulec import layout
from rules_sync.check import BASE_URL

PATH = layout.ROOT / layout.PAGES
FIELDS = ("title", "in", "kind", "hash", "fetched", "skip", "gone", "detail")
HEADER = ("# Every page of https://dsa.ulisses-regelwiki.de/, written by `make rules-sync`.\n"
          "# Edit only `skip` (here, or on a page). Status is derived: `make rules-coverage`.\n")
SEP = " / "


def key_of(url: str) -> str:
    return url[len(BASE_URL):] if url.startswith(BASE_URL) else url


@dataclass
class Registry:
    synced: "datetime.date | None" = None
    skip: dict = field(default_factory=dict)
    pages: dict = field(default_factory=dict)

    def skip_reason(self, key: str) -> "str | None":
        page = self.pages.get(key, {})
        if page.get("skip"):
            return page["skip"]
        trail = page.get("in", "")
        best = None
        for prefix, reason in self.skip.items():
            if trail == prefix or trail.startswith(prefix + SEP):
                if best is None or len(prefix) > len(best[0]):
                    best = (prefix, reason)
        return best[1] if best else None


def merge(old: Registry, crawl, today: datetime.date) -> Registry:
    if crawl.fatal_problems:
        raise ValueError("the crawl did not finish; pages.yaml not written:\n"
                         + "\n".join(str(p) for p in crawl.fatal_problems))
    new = Registry(synced=today, skip=dict(old.skip))
    for url, page in crawl.pages.items():
        key = key_of(url)
        before = old.pages.get(key, {})
        entry = {"title": page.title, "in": SEP.join(page.trail), "kind": page.kind}
        if page.hash:
            entry["hash"] = page.hash
            entry["fetched"] = before["fetched"] if before.get("hash") == page.hash else today
        for kept in ("skip",):
            if before.get(kept):
                entry[kept] = before[kept]
        if page.detail:
            entry["detail"] = page.detail
        new.pages[key] = entry
    for key, before in old.pages.items():
        if key not in new.pages:
            new.pages[key] = {**before, "gone": before.get("gone") or today}
    return new


def load(text: str) -> Registry:
    doc = yaml.safe_load(text) or {}
    return Registry(doc.get("synced"), dict(doc.get("skip") or {}), dict(doc.get("pages") or {}))


def _line(value) -> str:
    return yaml.safe_dump(value, default_flow_style=True, allow_unicode=True,
                          sort_keys=False, width=10**9).strip()


def dump(reg: Registry) -> str:
    out = [HEADER, f"synced: {reg.synced}\n" if reg.synced else "synced: null\n"]
    out.append("skip:\n" if reg.skip else "skip: {}\n")
    for prefix in sorted(reg.skip):
        out.append(f"  {_line({prefix: reg.skip[prefix]})[1:-1]}\n")
    out.append("pages:\n")
    for key in sorted(reg.pages):
        entry = {f: reg.pages[key][f] for f in FIELDS if reg.pages[key].get(f) is not None}
        out.append(f"  {_line(key)}: {_line(entry)}\n")
    return "".join(out)


def read(path: Path = PATH) -> Registry:
    return load(path.read_text(encoding="utf-8")) if path.exists() else Registry()


def write(reg: Registry, path: Path = PATH) -> None:
    path.write_text(dump(reg), encoding="utf-8")
```

If the round-trip test fails on a quoting detail of `_line`, fix `_line`, not the test.

- [ ] **Step 4: Run** `make test-rules-sync` → `OK`

- [ ] **Step 5: Commit** `git commit -m "feat(rules): pages.yaml, the registry of rule-website pages"`

---

### Task 5: `rulefiles.set_source_hash`

**Goal:** A checked, line-surgical edit that writes `source.hash` and `source.checked` into one rule file.

**Files:**
- Modify: `scripts/rules_review/rulefiles.py`, `scripts/rules_review/test_rulefiles.py`

**Acceptance Criteria:**
- [ ] `set_source_hash(path, hash, date)` replaces the `hash:` and `checked:` lines of a block-style `source:` mapping, keeps each line's trailing comment, and inserts `hash:` as the block's last line when it is absent.
- [ ] A flow-style `source: { … }` raises `EditRefused("source is a flow mapping; edit it by hand")`.
- [ ] `_write_checked` guards the edit: only `source.hash` and `source.checked` change.
- [ ] The diff of an edited file is exactly the changed lines (test compares with `difflib`, like the existing tests).

**Verify:** `make test-rules-review` → `OK` and `RULINGS.md is current`

**Steps:**

- [ ] **Step 1: Failing tests** — add to `test_rulefiles.py`, using the file's existing temp-root pattern (read how the existing tests point `rf.ROOT` at a temp copy and do the same):

```python
BLOCK = """\
id: SA_2
source:
  url: https://dsa.ulisses-regelwiki.de/KSF_X.html
  checked: 2026-09-24
  hash: null               # filled in by the drift check
reviewed: null
clauses: []
"""


class SourceHashTests(unittest.TestCase):
    # Same pattern as EditTests: an absolute temp path (`ROOT / abs` is `abs`).
    def setUp(self):
        self.dir = Path(tempfile.mkdtemp())
        self.path = self.dir / "SA_2.yaml"
        self.path.write_text(BLOCK, encoding="utf-8")

    def tearDown(self):
        shutil.rmtree(self.dir)

    def test_writes_hash_and_checked_keeps_the_comment(self):
        rf.set_source_hash(self.path, "sha256:" + "a" * 64, DAY)
        new = self.path.read_text(encoding="utf-8").splitlines()
        changed = [l for l in difflib.ndiff(BLOCK.splitlines(), new) if l[:2] in ("+ ", "- ")]
        self.assertEqual(changed, [
            "-   checked: 2026-09-24",
            "-   hash: null               # filled in by the drift check",
            "+   checked: 2026-09-23",
            "+   hash: sha256:" + "a" * 64 + "               # filled in by the drift check",
        ])

    def test_a_missing_hash_line_is_added_to_the_block(self):
        self.path.write_text(BLOCK.replace("  hash: null               # filled in by the drift check\n", ""),
                             encoding="utf-8")
        rf.set_source_hash(self.path, "sha256:" + "b" * 64, DAY)
        data = yaml.safe_load(self.path.read_text(encoding="utf-8"))
        self.assertEqual(data["source"]["hash"], "sha256:" + "b" * 64)
        self.assertEqual(data["reviewed"], None)

    def test_flow_source_is_refused(self):
        self.path.write_text(RULE, encoding="utf-8")      # RULE's source is a flow mapping
        with self.assertRaises(rf.EditRefused):
            rf.set_source_hash(self.path, "sha256:" + "c" * 64, DAY)
        self.assertEqual(self.path.read_text(encoding="utf-8"), RULE)
```

If `ndiff` pairs the lines in another order, compare as sets; the point is that only those lines change.

- [ ] **Step 2: Run** `make test-rules-review` → FAIL.

- [ ] **Step 3: Implement** in `rulefiles.py`, after `set_reviewed`:

```python
def set_source_hash(path, digest, date=None):
    """Record the hash of the page the rule was checked against, and the day it was."""
    path = ROOT / path
    lines = _read(path)
    rng = key_range(lines, "source")
    if rng is None:
        raise EditRefused("no source block")
    start, end = rng
    if lines[start].split("#", 1)[0].strip() != "source:":
        raise EditRefused("source is a flow mapping; edit it by hand")
    child = indent(lines[start + 1])
    date = date or datetime.date.today()
    new_lines = list(lines)

    def put(key, value):
        nonlocal end
        at = next((i for i in range(start + 1, end)
                   if indent(new_lines[i]) == child and new_lines[i].strip().startswith(f"{key}:")), None)
        text = " " * child + f"{key}: {value}"
        if at is None:
            new_lines.insert(end, text)
            end += 1
            return
        if m := re.search(r"\s+#.*$", new_lines[at]):
            text += m.group(0)
        new_lines[at] = text

    put("checked", date.isoformat())
    put("hash", digest)

    def expect(data):
        data["source"]["checked"] = date
        data["source"]["hash"] = digest

    _write_checked(path, lines, new_lines, expect)
```

`key_range` returns `block_end(lines, i, 0)`, which can include trailing blank or comment lines. Before the first `put`, move `end` back while `lines[end - 1]` is blank or is a comment at indent 0, so an inserted `hash:` lands inside the block.

- [ ] **Step 4: Run** `make test-rules-review` → `OK`

- [ ] **Step 5: Commit** `git commit -m "feat(rules-review): write a rule's source hash and checked date"`

---

### Task 6: `make rules-sync`

**Goal:** One command that crawls the site, writes `pages.yaml`, and on request adopts page hashes into rule files.

**Files:**
- Create: `scripts/rules_sync/sync.py`, `scripts/rules_sync/__main__.py`, `scripts/rules_sync/test_sync.py`
- Modify: `Makefile`

**Acceptance Criteria:**
- [ ] `python -m rules_sync sync [--max-age-hours N] [--adopt] [--adopt-ids SA_40,ADV_4] [--pages PATH] [--rules-root PATH]`.
- [ ] Default `--max-age-hours 20`: a run stopped half-way and started again the same day refetches nothing it already has. `MAX_AGE=0` refetches all.
- [ ] Prints: per top category the number of rule, index and broken pages; every problem; the number of pages whose hash changed since the last sync (`changed since <date>`); the number of network calls.
- [ ] A fatal problem: print it, write nothing, exit 1.
- [ ] `--adopt`: for each rule source whose `hash` is null and whose URL is a `kind: rule` page in the new registry, `set_source_hash(path, page hash, today)`. `--adopt-ids`: the same for the named rule ids, whether their hash is null or not. A named id with no known page is reported and makes the exit code 1. Each write is printed (`adopted SA_40 ← KSF_Aufmerksamkeit.html`).
- [ ] A rule with several sources (`also[].url`) is adopted from `source.url` only; its `also` pages count for coverage, not for its one `hash`.
- [ ] Makefile:

```make
# Crawl every page of the rule website into specs/rules/pages.yaml (about one page a second; a
# first run takes long, a re-run the same day resumes from .cache/). MAX_AGE=0 refetches all.
# ADOPT=1 writes the page hash into every rule file that has none; ADOPT=SA_40,ADV_4 into those.
rules-sync:
	$(RULES_SYNC) -m rules_sync sync $(if $(MAX_AGE),--max-age-hours $(MAX_AGE),) \
		$(if $(filter 1,$(ADOPT)),--adopt,$(if $(ADOPT),--adopt-ids $(ADOPT),))
```

**Verify:** `make test-rules-sync` → `OK`

**Steps:**

- [ ] **Step 1: Failing tests** (`test_sync.py`): build a temp rules root with two rule files (one with `hash: null`, one with a hash) and a `FakeFetcher` site (reuse the helpers from `test_resolve.py` by importing them). Assert:
  - `sync.run(fetcher, pages_path, rules_root, today=D1)` writes a `pages.yaml` whose `pages` holds the site's rule and index pages, and returns 0;
  - with `adopt=True` the null-hash file now carries the page's hash and `checked: D1`, and the other file is byte-identical;
  - with `adopt_ids=["SA_9"]` for an id with no page, the return is 1 and nothing is adopted;
  - a site with a missing index page returns 1 and leaves an existing `pages.yaml` byte-identical.

  `sync.run` takes `rules_root` and points `rulefiles.ROOT` at it for the call (use `mock.patch.object(rulefiles, "ROOT", rules_root)` in the test; in `run`, pass paths relative to `rulefiles.ROOT`).

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** `sync.py`:

```python
"""make rules-sync: crawl the rule website into specs/rules/pages.yaml.

    make rules-sync                 # crawl, hash, write pages.yaml
    make rules-sync MAX_AGE=0       # ignore today's cached copies
    make rules-sync ADOPT=1         # also give every rule file with no hash its page's hash
    make rules-sync ADOPT=SA_40     # re-adopt a rule after it was reprocessed
"""
from __future__ import annotations

import argparse
import collections
import datetime
import sys
from pathlib import Path

from rulec import layout
from rules_review import rulefiles
from rules_sync import check, pages, resolve


def adopt(reg, sources, ids, all_null, today) -> int:
    status = 0
    firsts = {}
    for s in sources:
        firsts.setdefault(s.rule_id, s)          # source.url comes before also[] in rule_sources
    for rule_id, s in sorted(firsts.items()):
        if not (all_null and s.hash is None) and rule_id not in ids:
            continue
        page = reg.pages.get(pages.key_of(s.url))
        if not page or page.get("kind") != "rule" or page.get("gone"):
            if rule_id in ids:
                print(f"cannot adopt {rule_id}: {s.url} is not a current rule page")
                status = 1
            continue
        rulefiles.set_source_hash(s.path.relative_to(rulefiles.ROOT), page["hash"], today)
        print(f"adopted {rule_id} ← {pages.key_of(s.url)}")
    for missing in sorted(set(ids) - set(firsts)):
        print(f"cannot adopt {missing}: no rule file with a source url")
        status = 1
    return status


def report(crawl, old, new) -> None:
    counts = collections.Counter((p.trail[0], p.kind) for p in crawl.pages.values())
    for top in sorted({t for t, _ in counts}):
        print(f"{top:<45} {counts[top, 'rule']:>5} rule  {counts[top, 'index']:>4} index  "
              f"{counts[top, 'broken']:>3} broken")
    for p in crawl.problems:
        print(p)
    changed = [k for k, e in new.pages.items()
               if e.get("hash") and old.pages.get(k, {}).get("hash") not in (None, e["hash"])]
    print(f"\n{len(changed)} page(s) changed since {old.synced}")


def run(fetcher, pages_path=pages.PATH, rules_root=layout.ROOT, *, adopt_all=False,
        adopt_ids=(), today=None) -> int:
    today = today or datetime.date.today()
    crawl = resolve.crawl(fetcher)
    old = pages.read(pages_path)
    try:
        new = pages.merge(old, crawl, today)
    except ValueError as exc:
        print(exc)
        return 1
    pages.write(new, pages_path)
    report(crawl, old, new)
    status = 0
    if adopt_all or adopt_ids:
        status = adopt(new, check.rule_sources(rules_root), set(adopt_ids), adopt_all, today)
    print(f"{fetcher.network_calls} network call(s) made")
    return status


def main(argv=None) -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--max-age-hours", type=float, default=20)
    ap.add_argument("--adopt", action="store_true")
    ap.add_argument("--adopt-ids", default="")
    ap.add_argument("--pages", type=Path, default=pages.PATH)
    ap.add_argument("--rules-root", type=Path, default=layout.ROOT)
    a = ap.parse_args(argv)
    fetcher = check.Fetcher(max_age=datetime.timedelta(hours=a.max_age_hours))
    ids = [i for i in a.adopt_ids.split(",") if i]
    sys.exit(run(fetcher, a.pages, a.rules_root, adopt_all=a.adopt, adopt_ids=ids))
```

`from rules_review import rulefiles` works from `scripts/` as a namespace package; `rulefiles` itself puts `scripts/` on `sys.path` and imports `rulec.layout`.

`__main__.py`:

```python
import sys

from rules_sync import sync

COMMANDS = {"sync": sync.main}

if len(sys.argv) < 2 or sys.argv[1] not in COMMANDS:
    sys.exit(f"usage: python -m rules_sync {{{'|'.join(COMMANDS)}}} [options]")
COMMANDS[sys.argv[1]](sys.argv[2:])
```

In this task `__main__.py` imports only `sync` and `COMMANDS = {"sync": sync.main}`. Task 7 adds the `coverage` import and its entry.

- [ ] **Step 4: Run** `make test-rules-sync` → `OK`

- [ ] **Step 5: Commit** `git commit -m "feat(rules): make rules-sync crawls the rule website into pages.yaml"`

---

### Task 7: `make rules-coverage`

**Goal:** An offline report of how many website pages are processed, per top category and per status, and which rule files to reprocess.

**Files:**
- Create: `scripts/rules_sync/coverage.py`, `scripts/rules_sync/test_coverage.py`
- Modify: `scripts/rules_sync/__main__.py`, `Makefile`

**Acceptance Criteria:**
- [ ] No network access; reads `pages.yaml` and the rule files only.
- [ ] Status of each `kind: rule` page, first match wins:
  1. `gone` — the page has `gone`;
  2. `skipped` — `skip_reason` is set;
  3. `new` — no rule source names the page;
  4. `changed` — a rule source names it with a non-null hash ≠ the page hash;
  5. `unhashed` — a rule source names it with a null hash;
  6. `reviewed` — every rule naming it is reviewed;
  7. `drafted` — otherwise.
- [ ] `kind: index` and `kind: broken` pages are counted on their own line, not in the statuses.
- [ ] Output: a table, one row per top category and a total row, columns `pages new skipped drafted reviewed changed unhashed gone`; then the sections, each only when not empty:
  - `changed:` one line per page: key, then the rule ids to reprocess;
  - `skipped but has rules:` a page that is skipped and still named by a rule;
  - `rules with an unknown page:` rule id, URL, and up to five `resolve.candidates` from the page titles.
- [ ] `--list STATUS` prints the page keys and titles of one status (e.g. `make rules-coverage LIST=new`).
- [ ] Exit code 0, or 1 with `--check` when a page is `changed` or a rule has an unknown page.
- [ ] Makefile:

```make
# How many rule-website pages are processed, per category; which rules to reprocess. Offline.
# LIST=new (or skipped, drafted, …) lists one status's pages; CHECK=1 fails on changed pages.
rules-coverage:
	$(RULES_SYNC) -m rules_sync coverage $(if $(LIST),--list $(LIST),) $(if $(CHECK),--check,)
```

**Verify:** `make test-rules-sync` → `OK`

**Steps:**

- [ ] **Step 1: Failing tests** (`test_coverage.py`). Build a `Registry` in code and a list of `RuleSource`s; test `coverage.statuses(reg, sources)` returns the expected status per key for one page of each of the seven statuses, plus: a page named by two rules, one reviewed and one not → `drafted`; a page named by two rules with different hashes, one equal to the page → `changed`; a rule naming `X.html` not in the registry shows up in `coverage.unknown(reg, sources)`; `coverage.run(..., check=True)` returns 1 when there is a `changed` page and 0 when there is none.

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** `coverage.py` with `statuses(reg, sources) -> dict[key, str]`, `unknown(reg, sources) -> list[RuleSource]`, `render(reg, sources, st) -> str`, `run(pages_path, rules_root, list_status=None, check=False) -> int`, `main(argv)`. Group the sources by `pages.key_of(s.url)`. Top category is `entry["in"].split(" / ")[0]`. Use this status function:

```python
def status(reg, key, named) -> str:
    page = reg.pages[key]
    if page.get("gone"):
        return "gone"
    if reg.skip_reason(key):
        return "skipped"
    if not named:
        return "new"
    if any(s.hash and s.hash != page.get("hash") for s in named):
        return "changed"
    if any(s.hash is None for s in named):
        return "unhashed"
    return "reviewed" if all(s.reviewed for s in named) else "drafted"
```

Add `"coverage": coverage.main` to `COMMANDS` in `__main__.py`.

- [ ] **Step 4: Run** `make test-rules-sync` → `OK`

- [ ] **Step 5: Commit** `git commit -m "feat(rules): make rules-coverage counts processed pages and names rules to reprocess"`

---

### Task 8: First live crawl and hash baseline

**Goal:** A committed `specs/rules/pages.yaml` from a full live crawl, and the 76 rule files carrying the hash of the page they were drafted from.

**Files:**
- Create: `specs/rules/pages.yaml`
- Modify: the rule files `ADOPT=1` writes (only their `checked:` and `hash:` lines)

**Acceptance Criteria:**
- [ ] `make rules-sync` finishes with no fatal problem; the printed per-category table and the network-call count are pasted into the commit message.
- [ ] A second `make rules-sync` right after makes 0 network calls and leaves `pages.yaml` byte-identical (`git diff --exit-code specs/rules/pages.yaml`).
- [ ] `make rules-coverage` shows every one of the 13 top categories of the site root menu.
- [ ] Every URL in a rule file's `source.url` is a known page, or the `rules with an unknown page` list is reported to the owner with its candidates. The agent does not change a rule's URL on its own.
- [ ] `make rules-sync ADOPT=1` writes a hash into each rule file whose page is a current rule page; `git diff --stat` shows only `checked:`/`hash:` lines changed (`git diff -U0 specs/rules | grep '^[-+] ' | grep -vE '^[-+]\s+(checked|hash):'` prints nothing).
- [ ] After adoption, `make rules-coverage` shows 0 `changed` and 0 `unhashed` for pages whose rules were adopted.
- [ ] No `skip` is written by the agent. The owner sets skips after reading the coverage table.

**Verify:** `make rules-sync && git diff --exit-code specs/rules/pages.yaml && make rules-coverage`

**Steps:**

- [ ] **Step 1:** `make rules-sync` in the background (it runs for a long time: about one second per page; the size is not known before the first run). Watch its output. On a fatal problem, read the page it names and fix the crawl (a new task-3-style test first), then run again — the cache makes the re-run fast.
- [ ] **Step 2:** Run `make rules-sync` again; check 0 network calls and no diff.
- [ ] **Step 3:** `make rules-coverage`. Report the unknown-page list, if any, to the owner.
- [ ] **Step 4:** Commit `pages.yaml` alone: `git commit -m "data(rules): the first crawl of the rule website" -m "<table and counts>"`.
- [ ] **Step 5:** `make rules-sync ADOPT=1`; check the diff filter above prints nothing; `make test-rules-review`; `make rules-check`.
- [ ] **Step 6:** Commit the adopted rule files: `git commit -m "data(rules): record the page hash each rule was drafted from"`.

---

### Task 9: Documentation

**Goal:** The new targets, the file and the workflow are documented where the repo expects them.

**Files:**
- Modify: `AGENTS.md` (Build & Run list), `specs/rules/README.md` (a section "Pages and coverage"), `CHANGELOG.md` (`[Unreleased]` → `Added`)

**Acceptance Criteria:**
- [ ] `AGENTS.md` lists `make rules-sync`, `make rules-coverage` and `make test-rules-sync` with one line each, in the same style as `make rules-check`.
- [ ] `specs/rules/README.md` has a section that says: what `pages.yaml` holds; that only `skip` is edited by hand (page or trail prefix); the status list and its order; the reprocess loop (`rules-sync` → `rules-coverage` shows `changed` → reprocess the rule → `make rules-sync ADOPT=<id>`); and that `source.url` must be a page key in `pages.yaml`.
- [ ] `CHANGELOG.md` has one `Added` entry for the two targets and `pages.yaml`, with the counts from Task 8.
- [ ] The memory note `rules-page-tracking-plan` is updated to say the work is done and points at the README section.

**Verify:** `make test-rules-sync && make test-rules-review && make rules-check` → all pass

**Steps:**

- [ ] **Step 1:** Write the three doc changes.
- [ ] **Step 2:** Run the verify command.
- [ ] **Step 3:** Commit `git commit -m "docs(rules): page tracking, the two targets and the reprocess loop"`.
