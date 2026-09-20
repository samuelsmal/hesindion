"""Tests for scripts/rules_sync/normalise.py.

The fixtures are invented placeholder markup, not captures of real DSA rule
pages (Data Policy, AGENTS.md).

`rule_a.html`/`rule_b.html` carry the same made-up "Platzhalter-Regel" text
but differ in every markup dimension the normaliser needs to be stable
across: `<br>` vs `<br/>`, `&nbsp;` vs the `&#160;` numeric entity, whitespace
runs from re-indentation, an extra wrapping `<span>` around inline text, and
entirely different `<head>`/`<style>`/`<script>`/`<nav>`/`<footer>` chrome
around the same content. `rule_c_different.html` carries genuinely different
placeholder text, to prove the hash isn't constant.

`rule_d_dynamic1.html`/`rule_d_dynamic2.html` (fix round 1, ruling 3) are a
regression guard modelled on the real bug this round fixed: they reproduce
dsa.ulisses-regelwiki.de's actual DOM shape (`#main` > `.mod_article` >
`.ce_text`, verified by fetching 6 real pages -- see task-5-report.md) with a
`.t4c_quickcontact_form`/`.captcha_text` CAPTCHA widget carrying *different*
per-render challenge text in each fixture, once outside `#main` and once
(deliberately) inside it. Same rule text, different dynamic noise -- this is
the cheap, fixture-only check that would have caught the original bug
without a live fetch.
"""
import pathlib

import pytest

from scripts.rules_sync.normalise import hash_html, normalise_html

FIXTURES = pathlib.Path(__file__).parent / "fixtures"


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def test_differently_marked_up_captures_normalise_to_the_same_text():
    assert normalise_html(_read("rule_a.html")) == normalise_html(_read("rule_b.html"))


def test_differently_marked_up_captures_hash_identically():
    assert hash_html(_read("rule_a.html")) == hash_html(_read("rule_b.html"))


def test_hash_has_the_sha256_prefix_form():
    h = hash_html(_read("rule_a.html"))
    assert h.startswith("sha256:")
    assert len(h) == len("sha256:") + 64


def test_genuinely_different_text_hashes_differently():
    assert hash_html(_read("rule_a.html")) != hash_html(_read("rule_c_different.html"))


def test_normalised_text_excludes_style_and_script_content():
    text = normalise_html(_read("rule_a.html"))
    assert "color: #123456" not in text
    assert "console.log" not in text


def test_normalised_text_excludes_chrome_outside_main():
    text = normalise_html(_read("rule_a.html"))
    assert "Platzhalter Verlag" not in text  # footer
    assert "Start" not in text.split()  # nav link text, as a whole word


def test_br_becomes_a_word_boundary_not_glued_text():
    text = normalise_html(_read("rule_a.html"))
    assert "Spielmechanik. Zweite Zeile" in text


def test_non_breaking_space_becomes_a_regular_space():
    text = normalise_html(_read("rule_a.html"))
    assert "\xa0" not in text
    assert "Wert: 3 Punkte" in text


def test_whitespace_runs_collapse_to_a_single_space():
    text = normalise_html(_read("rule_a.html"))
    assert "  " not in text


def test_result_is_stripped_of_leading_and_trailing_whitespace():
    text = normalise_html(_read("rule_a.html"))
    assert text == text.strip()


def test_nfc_normalises_combining_characters():
    # "ö" as one precomposed codepoint (U+00F6) vs "o" + combining diaeresis
    # (U+006F U+0308) must normalise -- and therefore hash -- identically.
    precomposed = "<main><p>Prüfung</p></main>"
    decomposed = "<main><p>Prüfung</p></main>"
    assert hash_html(precomposed) == hash_html(decomposed)


@pytest.mark.parametrize("name", ["rule_a.html", "rule_b.html", "rule_c_different.html"])
def test_normalise_never_raises_on_the_fixtures(name):
    normalise_html(_read(name))


# --- Fix round 1: real DOM shape, per-render-random CAPTCHA widget ---------

def test_table_cells_with_no_separating_whitespace_do_not_glue_together():
    # <td>A</td><td>B</td> with nothing between the tags must not become "AB".
    html = "<main><table><tr><td>Erste Spalte</td><td>Zweite Spalte</td></tr></table></main>"
    text = normalise_html(html)
    assert "Erste SpalteZweite Spalte" not in text
    assert "Erste Spalte Zweite Spalte" in text


def test_dynamic_captcha_widget_outside_main_does_not_affect_the_hash():
    text = normalise_html(_read("rule_d_dynamic1.html"))
    assert "addieren" not in text
    assert "captcha" not in text.lower()


def test_dynamic_captcha_widget_inside_main_is_still_stripped():
    # rule_d_dynamic2.html deliberately puts the widget *inside* #main --
    # the explicit selector strip must catch it there too, not just rely on
    # #main scoping to exclude it structurally.
    text = normalise_html(_read("rule_d_dynamic2.html"))
    assert "Summe" not in text
    assert "captcha" not in text.lower()


def test_same_rule_text_with_different_dynamic_widget_content_hashes_identically():
    assert hash_html(_read("rule_d_dynamic1.html")) == hash_html(_read("rule_d_dynamic2.html"))
