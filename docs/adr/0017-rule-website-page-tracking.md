# ADR-0017: Tracking the Rule Website's Pages

## Status

Accepted, 2026-09-27.

## Context

ADR-0012 makes <https://dsa.ulisses-regelwiki.de/> the normative rule source: every rule file
under `specs/rules/` names the page it was drafted from in `source.url`. Two questions had no
answer:

- **How much of the site is processed?** Nobody could say how many rule pages the site has, or
  which of them no rule file covers yet.
- **Which rules must be reprocessed?** The site's text changes (errata, new books), and a rule file
  drafted from an older text goes stale with no sign.

The branch `feat/rules-data-pipeline` held a page normaliser, a cached fetcher and an index
crawler, inside an agent pipeline with calibration workspaces, leak guards and an Optolith identity
check. The owner ruled that pipeline out (its gate failed); the three modules were sound.

## Decision

**A generated registry, `specs/rules/pages.yaml`, one line per page of the site.** Each line holds
the page's URL key (relative to the site root), title, trail (`in:`, the anchor texts by which the
crawl reached it), `kind`, and for a rule page the `hash` of its text and the date that hash was
first seen (`fetched`). `make rules-sync` writes it; a person edits only `skip`. Tools: the package
`scripts/rules_sync/`; `make rules-sync` (network) and `make rules-coverage` (offline). Usage is in
`specs/rules/README.md`, "Pages and coverage".

**Status is derived, never stored.** `rules-coverage` computes each rule page's status (`gone`,
`skipped`, `new`, `changed`, `unhashed`, `reviewed`, `drafted`, first match wins) from
`pages.yaml` and the rule files' `source` blocks. The page → rule ids map is not stored either:
`source.url` already says it, and a second copy could disagree with it.

**`fetched` is the date the hash was first seen**, not the date of the last fetch, and a top-level
`synced:` records the run. Otherwise every sync would rewrite every line, and the diff would hide
the pages that changed.

**The hash is `sha256` of the page's normalised text** (`normalise.py`, ported unchanged from
`feat/rules-data-pipeline` with its tests as the contract): the `#main` container only, scripts,
styles and the site's dynamic widget removed, whitespace folded, NFC. A rule file carries the hash
of its page in `source.hash`; a page whose hash differs is `changed`. `make rules-sync ADOPT=<ids>`
writes a page's current hash into a rule file after the rule was reprocessed; `ADOPT=1` gives every
rule file with no hash its first baseline. A rule with no hash is `unhashed`, not `changed`, so the
first crawl did not flag every rule.

**The crawl starts at the site's own top menu and follows only links the site publishes.** It
follows the sub-menu anchors (`a.ulSubMenu`) and every same-site `.html` link inside `#main`, on
every page, rule pages included. No URL is built from an id or a name: the site uses at least three
unrelated URL shapes, and no rule produces them all. Content links that are cross-references wait
until no index link is left, so a page's trail is the site's own index trail where it has one:
plain breadth-first order moved 650 of the 5230 pages of 2026-09-26 into another top category.

**One spelling per URL (2026-09-27).** The crawl first kept each `href` byte for byte. But the site
serves one page under `ö`, `%C3%B6` and `%c3%b6`, under `(` and `%28`, and under a query's `%20`
and `+`: 195 pages were listed twice with the same hash, and 6 rule files citing `%20` found no
page. `check.canonical_url` now spells every URL one way: non-ASCII as NFC UTF-8 escapes, the
unreserved characters and `()!*'` bare, a query's space as `+`, a path's as `%20`. Escapes that
carry meaning (`%2F`, `%26`, `%2B`, …) and escapes that are no UTF-8 are kept. Letter case is not
folded: `Best_Hund.html` and `best_hund.html` gave different hashes. `pages.load` re-keys an older
file the same way, so a spelling change marks nothing `gone`.

**A page's `kind` comes from signals the site gives, in this order:**

1. The site's search module (`.mod_search`) → `broken`, not followed. The site answers a URL it has
   no page at with a search for the name in it; its results are spelling variants, not links.
2. Sub-menu anchors → `index`, unless the page has rule text of its own: less than
   `MENU_LINK_SHARE` (0.5) of its `#main` text is anchor text. Then it is `rule`, hashed, and its
   menu is still followed. Calibration, 2026-09-27: of 107 menu pages with text, the extended-combat
   menu page (headings and its menu inside `#main`) had 0.61, the highest page with rule text 0.47.
   Before this, the rules every Zustand shares (`GR_Zustand.html`), `Kampfregeln.html` and the top
   categories' introductions had no hash.
3. A container that is a list of links → `index`: the site's selection grid (`.body_einzeln`,
   `zauberauswahl.html` and its kind), or at least `LISTING_LINKS` (3) links making up
   `LISTING_SHARE` (0.7) of the text. Calibration on the 4582 cached rule pages of 2026-09-26:
   pages with rule text ran from 0 to 0.625, the two overview pages had 0.78 and 0.85; 0.5 would
   have taken four pages of rule text. Read as rule pages, the selection pages hid every spell,
   liturgy and talent behind them.
4. Otherwise the normaliser decides: text → `rule`; an empty container → `broken` (the text is
   rendered client-side, or outside `#main`).

**Skips are reasons, per page or per trail prefix.** A top-level `skip:` map keyed by a trail
prefix skips a subtree with one reason; the longest prefix wins, a page's own `skip` wins over
both. The owner skipped *Wege der Vereinigungen - ab 18 Jahre* (2026-09-27, not part of the app for
now) by its trail, not by the `WdV` URL prefix: 262 pages carry the trail and only 107 the prefix,
and the two `WdV` pages outside the trail are an index and a broken page.

**Fetching is polite and a partial crawl writes nothing.** One network request a second at most,
a disk cache under `.cache/rules_sync/` (a same-day re-run resumes from it; `MAX_AGE=0` refetches).
A timeout, a dropped connection, a 5xx or a 429 is tried again, 3 attempts in all, 60 s each (a
search answer took 29 s). A 404 or 410 is a note, not a failure: the page is left out and a page
`pages.yaml` knew becomes `gone`. Any other failure is fatal and `pages.yaml` is not written,
because a page that could not be fetched may be an index with everything behind it missing.

**Not ported** from `feat/rules-data-pipeline`: the agent pipeline (`propose.py`,
`rule_graph.py`), the calibration workspace, the leak guards and the Optolith / `rules.db` identity
confirmation.

## Consequences

- `make rules-coverage` answers "how much is processed" per category, and `CHECK=1` fails on a
  `changed` page, a rule whose page is unknown and a rule citing a page that is no rule page. A
  hook or a script can gate on it.
- The reprocess loop is mechanical: `rules-sync` → `rules-coverage` shows `changed` and the rule
  ids → reprocess the rule → `ADOPT=<id>`.
- A full crawl needs the network and takes long (about a page a second, over 8000 pages); a
  warm-cache run takes about ten minutes. Tests never touch the network.
- The classification thresholds are calibrated on the site as it was on 2026-09-26/27. A redesign
  of the site can move pages between `index`, `rule` and `broken`; the crawl's report and the diff
  of `pages.yaml` show it, and the thresholds' comments in `resolve.py` name their calibration.
- A menu page that is a rule page hashes its intro text only (its menu sits outside `#main`), but a
  menu inside `#main` is part of the hash: a new sub-page listed there shows as `changed`.
- `pages.yaml` is large (one line per page), but a sync changes only the lines of pages that
  changed, appeared or went: its diff is the record of what changed on the site.
