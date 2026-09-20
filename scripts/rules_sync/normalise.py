"""Deterministic normalisation of a DSA 5 rule-wiki page's rule text.

Given the raw HTML of a wiki page, extracts the visible rule text and reduces
it to a stable, hashable form. The goal: two captures of the *same* rule text
that differ only in markup (a `<br>` written as `<br/>`, a non-breaking space
where the other capture has a regular one, re-indented/reflowed whitespace, an
extra wrapping `<span>`, a stylesheet or script tag that changed) must hash
identically. A capture whose rule *text* actually changed must not.

This module has no model and no network access -- see check.py for the piece
that fetches pages and compares hashes. See the Task 5 report
(.superpowers/sdd/2026-09-20-rules-pipeline-and-authoring/task-5-report.md,
including the fix-round-1 section) for the live-site evidence behind the
`#main` container choice and the quick-contact/CAPTCHA strip below -- both
were verified against real https://dsa.ulisses-regelwiki.de/ pages, not
guessed.
"""
from __future__ import annotations

import hashlib
import re
import unicodedata

from bs4 import BeautifulSoup

_WHITESPACE_RE = re.compile(r"\s+")
_NBSP = "\xa0"

# Present on every page of this site (verified: exactly one match on each of
# 6 real pages fetched during fix round 1 -- site root, an index page, a
# sub-index page, and 3 rule pages), entirely outside #main, and its CAPTCHA
# challenge text is regenerated on *every* HTTP response -- confirmed by
# diffing two live fetches of the same URL one second apart, which differed
# in nothing else. #main scoping already excludes it structurally; this
# selector strips it explicitly too (belt and braces), in case some page
# nests it differently.
_DYNAMIC_WIDGET_SELECTOR = ".t4c_quickcontact_form, .captcha_text, [id^='captcha_text_']"


def normalise_html(html: str) -> str:
    """Reduce a wiki page's HTML to a stable plain-text form of its rule text.

    Steps, in order:
    1. Drop `<script>`/`<style>` tags entirely -- their content is not rule
       text, but BeautifulSoup's `get_text()` would otherwise include it
       verbatim (a well-known gotcha), so a CSS/JS-only edit would otherwise
       register as a rule change.
    2. Strip the site-wide quick-contact widget and its CAPTCHA span
       (`_DYNAMIC_WIDGET_SELECTOR`) -- see the comment on that constant. This
       runs before step 3 so it works regardless of where a page happens to
       put the widget, not just the common case step 3 already excludes it
       from.
    3. Scope extraction to `#main` (verified present, unique, and containing
       the rule text on every real page fetched -- see module docstring),
       falling back to the semantic `<main>` tag, then `<body>`, then the
       whole document, for robustness against a page this site doesn't use
       the same template for. This keeps navigation/header/footer chrome,
       which changes for reasons unrelated to any single rule, out of the
       hash.
    4. Turn every `<br>` (`<br>`, `<br/>`, `<br />` -- the HTML parser folds
       all of these to the same tag regardless of how the source spelled it)
       into a literal newline before the tag structure is discarded, so text
       on either side of an intentional line break doesn't get glued together
       into one word.
    5. Extract text with a space separator between nodes (`get_text(" ")`),
       so adjacent tags with no whitespace between them in the source (e.g.
       `<td>A</td><td>B</td>`) don't get glued into one word either. Combined
       with the whitespace-run collapse in step 7, an extra separator where
       the source already had real whitespace is harmless -- it collapses
       right back down to the single space that was already going to be
       there.
    6. Replace non-breaking spaces (both the decoded `&nbsp;`/`&#160;`
       entity, which BeautifulSoup turns into U+00A0, and a raw U+00A0 byte)
       with a regular space.
    7. Collapse any run of whitespace (spaces, tabs, the newlines introduced
       above, real newlines from source indentation, the separators from
       step 5) down to a single space, then strip leading/trailing
       whitespace -- markup reflow or re-indentation must not register as a
       rule change.
    8. NFC-normalise so a precomposed character (e.g. "ö", U+00F6) and its
       decomposed form (`o` + combining diaeresis, U+006F U+0308) hash
       identically.
    """
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["script", "style"]):
        tag.decompose()

    for widget in soup.select(_DYNAMIC_WIDGET_SELECTOR):
        widget.decompose()

    content = soup.find(id="main") or soup.find("main") or soup.find("body") or soup

    for br in content.find_all("br"):
        br.replace_with("\n")

    text = content.get_text(" ")
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
