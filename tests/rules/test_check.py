"""Tests for scripts/rules_sync/check.py.

Exercises the four-state report (ok / drifted / unverified / structure-changed
-- the last added in fix round 2) and the on-disk cache/rate-limit contract --
a second run against a warm cache must make zero network calls (Task 5
acceptance criterion). No real network access and no real rule text:
`Fetcher` is driven with an in-memory HTTP double, and the placeholder rule
text below is invented, not a capture of any real page.
"""
import textwrap
import time

import pytest
import yaml

from scripts.rules_sync.check import Fetcher, UNVERIFIED_HASH, check_rule, run
from scripts.rules_sync.normalise import hash_html

PLACEHOLDER_HTML = "<html><body><main><p>Platzhalter-Regeltext, Version {n}.</p></main></body></html>"


class FakeResponse:
    def __init__(self, text: str):
        self.text = text

    def raise_for_status(self):
        pass


class FakeSession:
    """Counts every `.get()` call and serves canned HTML keyed by URL, so
    tests can assert on call counts without touching the network."""

    def __init__(self, pages: dict):
        self.pages = pages
        self.calls = []

    def get(self, url, headers=None, timeout=None):
        self.calls.append(url)
        return FakeResponse(self.pages[url])


def make_fetcher(tmp_path, pages: dict, delay_patch=None) -> tuple[Fetcher, FakeSession]:
    session = FakeSession(pages)
    fetcher = Fetcher(cache_dir=tmp_path / "cache", session=session)
    return fetcher, session


def write_rule(tmp_path, filename: str, *, url: str, checked: str, hash_: str) -> None:
    (tmp_path / filename).write_text(
        yaml.dump({
            "id": filename.removesuffix(".yaml"),
            "subgroup": "none",
            "source": {"url": url, "checked": checked, "hash": hash_},
        })
    )


# --- Fetcher: cache + rate limiting ----------------------------------------

def test_second_fetch_of_the_same_url_makes_no_network_call(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    fetcher, session = make_fetcher(tmp_path, {url: PLACEHOLDER_HTML.format(n=1)})

    first = fetcher.get(url)
    second = fetcher.get(url)

    assert first == second
    assert len(session.calls) == 1
    assert fetcher.network_calls == 1


def test_a_fresh_fetcher_reading_a_warm_on_disk_cache_makes_no_network_call(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    cache_dir = tmp_path / "cache"

    warm_fetcher, warm_session = make_fetcher(tmp_path, {url: PLACEHOLDER_HTML.format(n=1)})
    warm_fetcher.get(url)
    assert warm_fetcher.network_calls == 1

    # A brand new Fetcher instance (as a second `make rules-sync-check` run
    # would construct) pointed at the same on-disk cache directory.
    cold_session = FakeSession({url: PLACEHOLDER_HTML.format(n=1)})
    cold_fetcher = Fetcher(cache_dir=cache_dir, session=cold_session)
    cold_fetcher.get(url)

    assert cold_fetcher.network_calls == 0
    assert cold_session.calls == []


def test_fetch_sleeps_the_configured_delay_only_on_a_real_fetch(tmp_path, monkeypatch):
    sleeps = []
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: sleeps.append(s))
    url = "https://example.invalid/Platzhalter.html"
    fetcher, _ = make_fetcher(tmp_path, {url: PLACEHOLDER_HTML.format(n=1)})

    fetcher.get(url)  # miss: sleeps
    fetcher.get(url)  # hit: no sleep

    from scripts.rules_sync.check import DELAY
    assert sleeps == [DELAY]


# --- check_rule: three states ------------------------------------------------

def test_unverified_marker_is_reported_without_any_fetch(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    write_rule(
        tmp_path, "SA_TEST.yaml",
        url="https://dsa.ulisses-regelwiki.de/UNVERIFIED",
        checked="1970-01-01",
        hash_=UNVERIFIED_HASH,
    )
    fetcher, session = make_fetcher(tmp_path, {})  # no pages registered at all

    result = check_rule(tmp_path / "SA_TEST.yaml", fetcher)

    assert result.status == "unverified"
    assert session.calls == []
    assert fetcher.network_calls == 0


def test_matching_hash_is_reported_ok(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    html = PLACEHOLDER_HTML.format(n=1)
    write_rule(tmp_path, "SA_TEST.yaml", url=url, checked="2026-09-20", hash_=hash_html(html))
    fetcher, _ = make_fetcher(tmp_path, {url: html})

    result = check_rule(tmp_path / "SA_TEST.yaml", fetcher)

    assert result.status == "ok"


def test_mismatched_hash_is_reported_drifted(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    write_rule(
        tmp_path, "SA_TEST.yaml", url=url, checked="2026-09-20",
        hash_="sha256:" + "1" * 64,
    )
    fetcher, _ = make_fetcher(tmp_path, {url: PLACEHOLDER_HTML.format(n=2)})

    result = check_rule(tmp_path / "SA_TEST.yaml", fetcher)

    assert result.status == "drifted"


def test_missing_content_container_is_reported_structure_changed(tmp_path, monkeypatch):
    # Fix round 2: a page with neither id="main" nor <main> must not be
    # silently treated as drifted (or ok) -- it's a distinct, louder state.
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    write_rule(tmp_path, "SA_TEST.yaml", url=url, checked="2026-09-20", hash_="sha256:" + "1" * 64)
    html_without_container = "<html><body><p>Kein main und kein #main hier.</p></body></html>"
    fetcher, _ = make_fetcher(tmp_path, {url: html_without_container})

    result = check_rule(tmp_path / "SA_TEST.yaml", fetcher)

    assert result.status == "structure-changed"
    assert url in result.detail  # ruling: message must name the URL


def test_fetch_failure_is_reported_drifted_not_a_crash(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    write_rule(tmp_path, "SA_TEST.yaml", url=url, checked="2026-09-20", hash_="sha256:" + "1" * 64)

    class RaisingSession:
        def get(self, url, headers=None, timeout=None):
            import requests
            raise requests.ConnectionError("nope")

    fetcher = Fetcher(cache_dir=tmp_path / "cache", session=RaisingSession())

    result = check_rule(tmp_path / "SA_TEST.yaml", fetcher)

    assert result.status == "drifted"
    assert "fetch failed" in result.detail


# --- run(): table + exit code ------------------------------------------------

def test_run_exits_zero_when_nothing_drifted(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    html = PLACEHOLDER_HTML.format(n=1)
    write_rule(tmp_path, "SA_OK.yaml", url=url, checked="2026-09-20", hash_=hash_html(html))
    write_rule(
        tmp_path, "SA_UNVERIFIED.yaml",
        url="https://dsa.ulisses-regelwiki.de/UNVERIFIED", checked="1970-01-01", hash_=UNVERIFIED_HASH,
    )
    fetcher, _ = make_fetcher(tmp_path, {url: html})

    code = run(rules_dir=tmp_path, fetcher=fetcher)

    assert code == 0
    out = capsys.readouterr().out
    assert "SA_OK" in out and "ok" in out
    assert "SA_UNVERIFIED" in out and "unverified" in out


def test_run_exits_nonzero_when_something_drifted(tmp_path, monkeypatch):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    write_rule(tmp_path, "SA_DRIFT.yaml", url=url, checked="2026-09-20", hash_="sha256:" + "1" * 64)
    fetcher, _ = make_fetcher(tmp_path, {url: PLACEHOLDER_HTML.format(n=3)})

    code = run(rules_dir=tmp_path, fetcher=fetcher)

    assert code == 1


def test_run_exits_nonzero_when_structure_changed(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr("scripts.rules_sync.check.time.sleep", lambda s: None)
    url = "https://example.invalid/Platzhalter.html"
    write_rule(tmp_path, "SA_STRUCT.yaml", url=url, checked="2026-09-20", hash_="sha256:" + "1" * 64)
    fetcher, _ = make_fetcher(tmp_path, {url: "<html><body><p>Kein Container.</p></body></html>"})

    code = run(rules_dir=tmp_path, fetcher=fetcher)

    assert code == 1
    out = capsys.readouterr().out
    assert "SA_STRUCT" in out and "structure-changed" in out
    assert "1 structure-changed" in out


def test_non_rule_yaml_files_are_skipped(tmp_path):
    (tmp_path / "SOURCES.yaml").write_text("pins: {}\n")
    from scripts.rules_sync.check import iter_rule_files
    assert list(iter_rule_files(tmp_path)) == []
