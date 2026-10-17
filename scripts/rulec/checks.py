"""The Probe table (`checks.yaml` beside the rules directory; Task 34): the caller's data about a
talent or spell check, which no rule encodes (TAL_7's `probe`, `anwendungsgebiet` and `belastung`
clauses say so). One row per talent or spell id:

- `attributes`: the Probe's three attributes, by the sheet's names (`attr.<name>`), in order
  (fertigkeitsproben.FP1);
- `hinderedByBelastung` (talents only): `true`, `false` or `maybe`, the fact
  `check.hinderedByBelastung` of a check on it (COND_1.belastung-reach);
- `applications` (talents only): the Anwendungsgebiete by their Optolith id (an int), the list
  `check.application` is picked from (fertigkeitsproben.FP8). An owned rule's numeric `sid2` names
  one of them (SA_9); `situations` resolves it into the name.

rulec writes the table into situations.json as `checks`; the harness hands it to the engine as the
app hands in its own data."""
import re

from . import hero as hero_mod
from . import yamlload
from .errors import RulecError

SUBJECT = re.compile(r"^(TAL|SPELL|LITURGY)_[0-9]+$")
KEYS = {"attributes", "hinderedByBelastung", "applications"}
TALENT_KEYS = {"hinderedByBelastung", "applications"}
ATTRIBUTES = list(hero_mod.ATTR.values())


def load(path):
    """`(table, errors)`: the rows of `path`, keyed by id; an application's id becomes a string key
    (as JSON has it)."""
    file = str(path)
    errors, table = [], {}

    def err(msg, line):
        errors.append(RulecError(msg, file, line))

    try:
        doc = yamlload.load(path)
    except Exception as e:                                  # YAML syntax
        return {}, [RulecError(f"yaml: {e}", file, None)]
    if not isinstance(doc, dict):
        return {}, [RulecError("the checks table is a mapping", file, 1)]
    for sid, row in doc.items():
        line = yamlload.line_of(doc, sid)
        if not SUBJECT.match(str(sid)):
            err(f"unknown check subject {sid}", line)
            continue
        if not isinstance(row, dict):
            err(f"{sid}: a row is a mapping", line)
            continue
        bad = False
        for k in row:
            if k not in KEYS:
                err(f"{sid}: unknown key {k}", line)
                bad = True
            elif k in TALENT_KEYS and not str(sid).startswith("TAL_"):
                err(f"{sid}: only a talent has {k}", line)
                bad = True
        attrs = row.get("attributes")
        if not (isinstance(attrs, list) and len(attrs) == 3 and all(a in ATTRIBUTES for a in attrs)):
            err(f"{sid}: attributes are three of {', '.join(ATTRIBUTES)}", line)
            bad = True
        flag = row.get("hinderedByBelastung", False)
        if flag not in (True, False, "maybe"):
            err(f"{sid}: hinderedByBelastung is true, false or maybe", line)
            bad = True
        apps = row.get("applications", {})
        if not (isinstance(apps, dict) and all(isinstance(i, int) and not isinstance(i, bool)
                                                and isinstance(n, str) for i, n in apps.items())):
            err(f"{sid}: an application is an int id and its name", line)
            bad = True
        if bad:
            continue
        out = {"attributes": list(attrs)}
        if "hinderedByBelastung" in row:
            out["hinderedByBelastung"] = flag
        if "applications" in row:
            out["applications"] = {str(i): n for i, n in apps.items()}
        table[str(sid)] = out
    return table, errors


def application_name(table, option, option2):
    """The name of the Anwendungsgebiet an owned rule's numeric `option2` names on the talent its
    `option` names; `option2` itself when the table does not know it (the player's own words, an
    unknown id)."""
    if isinstance(option2, bool) or not isinstance(option2, int):
        return option2
    apps = (table or {}).get(str(option), {}).get("applications", {})
    return apps.get(str(option2), option2)
