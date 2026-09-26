"""Where the rules live: `specs/rules/`.

The rule folders (`abilities/`, `core/`, …) and the shared `rulings.yaml` sit directly in the
root, next to what is not a rule: the situations, the sweeps and the Probe table. Every tool that
walks the rule files asks `rule_files` rather than globbing the root, so a situations file is never
read as a rule."""
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
ROOT = REPO / "specs" / "rules"

SITUATIONS = "situations"
SWEEPS = "sweeps"
CHECKS = "checks.yaml"
SHARED_RULINGS = "rulings.yaml"

# Entries of the root that are not rule files.
NOT_RULES = {SITUATIONS, SWEEPS, CHECKS, SHARED_RULINGS}


def rule_files(root: Path) -> list:
    """Every rule file under `root`, sorted: the YAML files outside `NOT_RULES`."""
    root = Path(root)
    return sorted(p for p in root.rglob("*.yaml") if p.relative_to(root).parts[0] not in NOT_RULES)
