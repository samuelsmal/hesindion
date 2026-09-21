"""Fixtures that apply to every test under `tests/`.

The live-agent guard lives here rather than in the module that needed it first.
A module-local autouse fixture protects exactly that module, which is not the
property anyone wants from a rule named "this suite makes zero model calls" --
and the incident it was written for arrived in a *new* test, which is precisely
the case a module-local fixture cannot cover (Task 6 fix round 2).
"""
import subprocess
from pathlib import Path

import pytest


@pytest.fixture(autouse=True)
def no_live_agent_calls(monkeypatch):
    """Fail any test that tries to spawn the real `claude` binary.

    `scripts/rules_sync/propose.py` shells out to headless Claude Code, so a
    test that reaches `main()` with the real `SubprocessRunner` makes billable
    model calls. That happened once: nothing failed, and the only symptom was
    the suite taking sixteen seconds longer. The contract is enforced here
    rather than asserted in a docstring.

    A test that fakes `subprocess.run` itself replaces this wrapper, which is
    what the `SubprocessRunner` unit tests rely on. Everything else passes
    through, so tests that shell out to `git` still work.
    """
    real = subprocess.run

    def guarded(argv, **kwargs):
        first = argv[0] if isinstance(argv, (list, tuple)) and argv else argv
        if Path(str(first)).name == "claude":
            raise AssertionError(
                f"a test tried to spawn the real agent ({argv!r}). "
                "Inject a FakeRunner: this suite makes zero model calls."
            )
        return real(argv, **kwargs)

    monkeypatch.setattr(subprocess, "run", guarded)
