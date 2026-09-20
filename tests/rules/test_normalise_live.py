"""Live-site idempotence check for scripts/rules_sync/normalise.py.

Fix round 1, ruling 2: fixture equality proved nothing about the real site --
all fixture tests in test_normalise.py passed while the pre-fix extraction
(falling back to `<body>`, which includes dsa.ulisses-regelwiki.de's
site-wide CAPTCHA widget) reported 100% drift against every real page,
because the CAPTCHA challenge text is regenerated on every HTTP response.
The binding criterion is idempotence against the *live* site: the same URL,
fetched twice with the cache bypassed, must hash identically; two genuinely
different rule pages must not.

Network-dependent by nature -- skips the whole module cleanly (not a
failure) if the live site can't be reached, via a session-scoped fixture
that does all three live fetches once and hands the results to both tests.
Nothing fetched here is written to disk or committed (Data Policy);
scripts/rules_sync/check.py's on-disk cache is a separate, git-ignored
concern this test does not touch.
"""
import time

import pytest
import requests

from scripts.rules_sync.normalise import hash_html

_HEADERS = {"User-Agent": "DSA-Companion-Scraper/1.0"}
_URL_A = "https://dsa.ulisses-regelwiki.de/KSF_Finte.html"
_URL_B = "https://dsa.ulisses-regelwiki.de/KSF_Wuchtschlag.html"


def _fetch(url: str) -> str:
    response = requests.get(url, headers=_HEADERS, timeout=15)
    response.raise_for_status()
    return response.text


@pytest.fixture(scope="module")
def live_fetches():
    """(finte_1, finte_2, wuchtschlag): KSF_Finte.html fetched twice, one
    second apart (matching the polite rate limit, cache bypassed -- this
    hits the network directly, not through check.py's Fetcher), plus
    KSF_Wuchtschlag.html once. Skips the module on any network failure."""
    try:
        finte_1 = _fetch(_URL_A)
        time.sleep(1.0)
        finte_2 = _fetch(_URL_A)
        time.sleep(1.0)
        wuchtschlag = _fetch(_URL_B)
    except requests.RequestException as exc:
        pytest.skip(f"live site unreachable, skipping live idempotence check: {exc}")
    return finte_1, finte_2, wuchtschlag


def test_same_url_fetched_twice_live_hashes_identically(live_fetches):
    finte_1, finte_2, _ = live_fetches
    assert hash_html(finte_1) == hash_html(finte_2)


def test_two_different_live_rule_pages_hash_differently(live_fetches):
    finte_1, _, wuchtschlag = live_fetches
    assert hash_html(finte_1) != hash_html(wuchtschlag)
