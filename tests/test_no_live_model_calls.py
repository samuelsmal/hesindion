"""The zero-model-call contract, proved from a module that does not define it.

This file exists to demonstrate reach. The guard was first written as an
autouse fixture inside `tests/rules/test_propose.py`, where pytest applied it
to that module and nothing else: a throwaway test in a sibling file called
`subprocess.run(["claude", "-p"])` and invoked the real binary on PATH. Since
the bug it was written for arrived in a new test, a guard that only covers one
existing file guards the wrong thing (Task 6 fix round 2).
"""
import subprocess

import pytest


def test_the_guard_reaches_a_module_that_does_not_define_it():
    with pytest.raises(AssertionError, match="zero model calls"):
        subprocess.run(["claude", "-p", "hello"], capture_output=True)


def test_the_guard_finds_claude_by_an_absolute_path_too():
    with pytest.raises(AssertionError, match="zero model calls"):
        subprocess.run(["/usr/local/bin/claude", "--version"], capture_output=True)


def test_the_guard_lets_every_other_command_through():
    completed = subprocess.run(["echo", "ok"], capture_output=True, text=True)
    assert completed.stdout.strip() == "ok"
