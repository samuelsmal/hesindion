"""Deterministic normalisation of a DSA 5 rule-website page's rule text.

Given the raw HTML of a rule-website page, extracts the visible rule text and reduces
it to a stable, hashable form. The goal: two captures of the *same* rule text
that differ only in markup (a `<br>` written as `<br/>`, a non-breaking space
where the other capture has a regular one, re-indented/reflowed whitespace, an
extra wrapping `<span>`, a stylesheet or script tag that changed) must hash
identically. A capture whose rule *text* actually changed must not.

This module has no model and no network access -- see check.py for the piece
that fetches pages and compares hashes. See the Task 5 report
(.superpowers/sdd/2026-09-20-rules-pipeline-and-authoring/task-5-report.md,
including the fix-round-1 and fix-round-2 sections) for the live-site
evidence behind the `#main` container choice and the quick-contact/CAPTCHA
strip below -- both were verified against real
https://dsa.ulisses-regelwiki.de/ pages, not guessed.
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

# Fix round 2 (extended in fix round 3): tags whose *boundary* (open and
# close) is a word break even with no whitespace in the source -- these are
# block-level elements, where HTML rendering itself forces a line break, so
# "<td>A</td><td>B</td>" reads as two words to a person even though the
# markup has no space between them. `br` is handled separately (it has no
# content of its own to bracket -- it *becomes* the boundary, see below), and
# deliberately not included here. `table`/`ul`/`ol` are deliberately left out
# too: they don't directly contain text nodes in normal markup (their
# `tr`/`li` children already carry the boundary).
#
# Fix round 3 added `dl`/`dt`/`dd`/`blockquote`/`pre` -- the round-2 ruling's
# list (written from memory) omitted these; a definition list is exactly the
# shape a stat block takes on a rules wiki ("<dl><dt>LE</dt><dd>30</dd>...")
# and was gluing without them, a regression against round 1's blanket
# separator that *did* separate these.
_BLOCK_BOUNDARY_TAGS = (
    "p", "div", "li", "tr", "td", "th",
    "h1", "h2", "h3", "h4", "h5", "h6",
    "section", "article",
    "dl", "dt", "dd", "blockquote", "pre",
)

# Inline tags (b, i, span, a, strong, em, sup, ...) are deliberately *not* in
# the list above and get no inserted boundary: "Der <b>Wucht</b>schlag" must
# stay "Wuchtschlag", not become "Wucht schlag" -- a cross-reference link or
# emphasis tag placed mid-word must not manufacture a space that was never in
# the rendered text. See the fix-round-2 report section for the reviewer's
# repro that caught the previous `get_text(" ")` approach getting this wrong.


class ContentContainerError(Exception):
    """Base class for "this page yielded no usable rule text" failures.

    A missing content container and a present-but-empty one are the same
    failure class -- in both cases this normaliser cannot say what part of
    the page is the rule text, so it must fail loudly rather than hand back
    a plausible-looking hash. check.py catches *this* class and surfaces
    both as its single `structure-changed` state; the two subclasses below
    exist because the remedies differ, and the message has to say which.
    """


class ContentContainerNotFound(ContentContainerError):
    """Raised when a page has neither `id="main"` nor a `<main>` element.

    Fix round 2: this site has no `<main>` element on any real page (fix
    round 1's finding) and its actual content container is `#main` -- but a
    future redesign could rename or drop that id. The original fallback
    chain (`#main` -> `<main>` -> `<body>` -> whole document) would silently
    degrade to `<body>` in that case, picking up the CAPTCHA widget again and
    reproducing the exact bug fix round 1 closed, just quietly. A missing
    content container is architecturally different from "the text changed"
    or "the network hiccuped" -- it means this normaliser no longer knows
    what part of the page is the rule, so it must fail loudly rather than
    guess. check.py surfaces this as its own `structure-changed` state.

    Remedy: the site's markup changed -- look at the page and update the
    container selection in `normalise_html` (or the rule's `source.url`).
    """


class ContentContainerEmpty(ContentContainerError):
    """Raised when the content container exists but yields no text.

    Fix round 4. `ContentContainerNotFound` only covered an *absent*
    container. Five real pages on the live site --
    `sf_kampfsonderfertigkeiten.html`, `Best_Tiere.html`,
    `ruestkammer.html`, `RS_Waffen.html`, `RS_Ruestung.html` -- have a
    present but **empty** `#main` in their raw HTML: their content is
    rendered client-side, or (verified for the first of them) sits outside
    `#main` entirely, under `#sub_header`. Those normalised to `""` and
    hashed to `sha256:e3b0c442...b855`, the SHA-256 of the empty string.
    Every such page therefore produced the *same* valid-looking hash, which,
    once written into a rule's `source.hash`, would have compared `ok`
    forever while verifying nothing -- the same class of silent failure as
    the pre-fix-round-1 CAPTCHA bug, just inverted (constant instead of
    always-changing).

    A container that is only whitespace, or only elements this module
    strips (`<script>`/`<style>`, the quick-contact/CAPTCHA widget), is the
    same case: after normalisation there is no rule text to hash.

    Remedy: the content is **not in the fetched HTML at all**, so no change
    to the container selector will help -- the URL is probably an index or
    client-rendered page and is not usable as a rule's `source.url`.
    """


def normalise_html(html: str) -> str:
    """Reduce a rule-website page's HTML to a stable plain-text form of its rule text.

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
       falling back only to the semantic `<main>` tag. If neither is present,
       raise `ContentContainerNotFound` rather than silently falling back to
       `<body>`/the whole document -- see that class's docstring. This keeps
       navigation/header/footer chrome, which changes for reasons unrelated
       to any single rule, out of the hash.
    4. Turn every `<br>` (`<br>`, `<br/>`, `<br />` -- the HTML parser folds
       all of these to the same tag regardless of how the source spelled it)
       into a literal newline before the tag structure is discarded, so text
       on either side of an intentional line break doesn't get glued together
       into one word.
    5. Insert a newline before and after every *block-level* tag
       (`_BLOCK_BOUNDARY_TAGS`) -- so `<td>A</td><td>B</td>` still reads as
       "A B", matching how a browser renders it. *Inline* tags (`<b>`, `<i>`,
       `<span>`, `<a>`, ...) get no inserted boundary, so `Der
       <b>Wucht</b>schlag` stays "Wuchtschlag", not "Wucht schlag" -- fix
       round 2's correction of a fix-round-1 regression that inserted a
       separator between *every* node, including mid-word inline tags.
    6. Extract text with no separator (`get_text()`) -- the boundaries
       inserted in steps 4 and 5 are now real text nodes, so no separator
       argument is needed or wanted; adding one again would reintroduce the
       mid-word-inline-tag bug this round fixed.
    7. Replace non-breaking spaces (both the decoded `&nbsp;`/`&#160;`
       entity, which BeautifulSoup turns into U+00A0, and a raw U+00A0 byte)
       with a regular space.
    8. Collapse any run of whitespace (spaces, tabs, the newlines introduced
       above, real newlines from source indentation) down to a single space,
       then strip leading/trailing whitespace -- markup reflow or re-
       indentation must not register as a rule change.
    9. NFC-normalise so a precomposed character (e.g. "ö", U+00F6) and its
       decomposed form (`o` + combining diaeresis, U+006F U+0308) hash
       identically.
    10. Fail if the result is empty. An empty extraction is never a valid
       rule page; it is the same "we don't know where the rule text is"
       failure as a missing container, and letting it through would hand
       every such page the SHA-256 of the empty string as a plausible,
       permanently-`ok` provenance hash -- see `ContentContainerEmpty`.

    Raises:
        ContentContainerNotFound: neither `id="main"` nor `<main>` exists in
            `html`.
        ContentContainerEmpty: the container exists but normalises to "".
        Both are `ContentContainerError`; callers that treat the two the
        same (check.py does, as one `structure-changed` state) catch that.
    """
    soup = BeautifulSoup(html, "html.parser")

    for tag in soup(["script", "style"]):
        tag.decompose()

    for widget in soup.select(_DYNAMIC_WIDGET_SELECTOR):
        widget.decompose()

    content = soup.find(id="main") or soup.find("main")
    if content is None:
        raise ContentContainerNotFound(
            'no content container: neither id="main" nor a <main> element '
            "exists in this page -- the site's markup changed; look at the "
            "page and update normalise.py's container selection"
        )

    for br in content.find_all("br"):
        br.replace_with("\n")

    for tag in content.find_all(_BLOCK_BOUNDARY_TAGS):
        tag.insert_before("\n")
        tag.insert_after("\n")

    text = content.get_text()
    text = text.replace(_NBSP, " ")
    text = _WHITESPACE_RE.sub(" ", text).strip()
    text = unicodedata.normalize("NFC", text)

    if not text:
        raise ContentContainerEmpty(
            'empty content container: id="main"/<main> exists but contains no '
            "text after normalisation -- the rule text is not in the fetched "
            "HTML at all (rendered client-side, or outside the container), so "
            "this page cannot be hashed as rule provenance"
        )

    return text


def hash_html(html: str) -> str:
    """Return the `sha256:<hex>` provenance hash (schema.json's `source.hash`
    shape) for a rule-website page's normalised rule text.

    Raises:
        ContentContainerError (`ContentContainerNotFound` /
            `ContentContainerEmpty`): see `normalise_html`. In particular
            this function never returns the hash of the empty string.
    """
    normalised = normalise_html(html)
    digest = hashlib.sha256(normalised.encode("utf-8")).hexdigest()
    return f"sha256:{digest}"
