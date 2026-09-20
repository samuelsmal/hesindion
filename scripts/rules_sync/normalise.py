"""Deterministic normalisation of a DSA 5 rule-wiki page's rule text.

Given the raw HTML of a wiki page, extracts the visible rule text and reduces
it to a stable, hashable form. The goal: two captures of the *same* rule text
that differ only in markup (a `<br>` written as `<br/>`, a non-breaking space
where the other capture has a regular one, re-indented/reflowed whitespace, an
extra wrapping `<span>`, a stylesheet or script tag that changed) must hash
identically. A capture whose rule *text* actually changed must not.

This module has no model and no network access -- see check.py for the piece
that fetches pages and compares hashes. See the Task 5 report
(.superpowers/sdd/2026-09-20-rules-pipeline-and-authoring/task-5-report.md)
for the reasoning behind each normalisation step.
"""
from __future__ import annotations

import hashlib
import re
import unicodedata

from bs4 import BeautifulSoup

_WHITESPACE_RE = re.compile(r"\s+")
_NBSP = "\xa0"


def normalise_html(html: str) -> str:
    """Reduce a wiki page's HTML to a stable plain-text form of its rule text.

    Steps, in order:
    1. Drop `<script>`/`<style>` tags entirely -- their content is not rule
       text, but BeautifulSoup's `get_text()` would otherwise include it
       verbatim (a well-known gotcha), so a CSS/JS-only edit would otherwise
       register as a rule change.
    2. Scope extraction to `<main>` (falling back to `<body>`, then the whole
       document) -- the same heuristic `scrape_effects.py` already uses for
       this site. This keeps navigation/header/footer chrome, which changes
       for reasons unrelated to any single rule, out of the hash.
    3. Turn every `<br>` (`<br>`, `<br/>`, `<br />` -- the HTML parser folds
       all of these to the same tag regardless of how the source spelled it)
       into a literal newline before the tag structure is discarded, so text
       on either side of an intentional line break doesn't get glued together
       into one word. No other tag boundary inserts whitespace: word
       separation elsewhere is whatever whitespace already exists in the
       source's text nodes. A source that puts two inline tags flush against
       each other with no separating whitespace (e.g. `<td>A</td><td>B</td>`)
       will extract as "AB" -- a deliberate simplification matching the
       normalisation recipe as specified, not a bug; real wiki markup and
       these fixtures both separate adjacent cells/paragraphs with whitespace.
    4. Replace non-breaking spaces (both the decoded `&nbsp;`/`&#160;` entity,
       which BeautifulSoup turns into U+00A0, and a raw U+00A0 byte) with a
       regular space.
    5. Collapse any run of whitespace (spaces, tabs, the newlines introduced
       above, real newlines from source indentation) down to a single space,
       then strip leading/trailing whitespace -- markup reflow or re-
       indentation must not register as a rule change.
    6. NFC-normalise so a precomposed character (e.g. "ö", U+00F6) and its
       decomposed form (`o` + combining diaeresis, U+006F U+0308) hash
       identically.
    """
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["script", "style"]):
        tag.decompose()

    content = soup.find("main") or soup.find("body") or soup

    for br in content.find_all("br"):
        br.replace_with("\n")

    text = content.get_text()
    text = text.replace(_NBSP, " ")
    text = _WHITESPACE_RE.sub(" ", text).strip()
    text = unicodedata.normalize("NFC", text)

    return text


def hash_html(html: str) -> str:
    """Return the `sha256:<hex>` provenance hash (schema.json's `source.hash`
    shape) for a wiki page's normalised rule text."""
    normalised = normalise_html(html)
    digest = hashlib.sha256(normalised.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"
