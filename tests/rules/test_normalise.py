"""Tests for scripts/rules_sync/normalise.py.

The two fixtures (`rule_a.html`, `rule_b.html`) are invented placeholder markup,
not captures of real DSA rule pages (Data Policy, AGENTS.md) -- they carry the
same made-up "Platzhalter-Regel" text but differ in every markup dimension the
normaliser needs to be stable across: `<br>` vs `<br/>`, `&nbsp;` vs the `&#160;`
numeric entity, whitespace runs from re-indentation, an extra wrapping `<span>`
around inline text, and entirely different `<head>`/`<style>`/`<script>`/`<nav>`/
`<footer>` chrome around the same `<main>` content. `rule_c_different.html`
carries genuinely different placeholder text, to prove the hash isn't constant.
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
