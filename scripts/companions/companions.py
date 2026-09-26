"""Companion builds: the Kat C price list and the purchase normaliser.

Animal companions raise attributes, talents, LE, AT and VW in column C
(Kodex des Schwertes p. 153); the column is the Regelwerk's Kostentabelle,
which ends at 25 and is continued here by its own linear rule.
See docs/plans/2026-09-24-companion-data-design.md §3.
"""

ATTRIBUTES = ("mu", "kl", "in", "ch", "ff", "ge", "ko", "kk")
NAMED_KINDS = ("advantage", "training", "trick", "ability")


class BuildError(ValueError):
    pass


def kat_c_step(value):
    """AP for raising a value to `value` (from value - 1) in column C."""
    return 3 if value <= 12 else 3 * (value - 11)


def raise_cost(start, end):
    return sum(kat_c_step(v) for v in range(start + 1, end + 1))


def lep_cost(count):
    """The nth bought LeP costs what raising a value to n costs."""
    return sum(kat_c_step(n) for n in range(1, count + 1))


def _valid_target(target):
    if target in ATTRIBUTES or target in ("vw", "at"):
        return True
    return target.startswith("talent:") and len(target) > len("talent:")


def normalise(purchase):
    """One YAML purchase -> the block's {kind, name|target, ap, ...}."""
    if not isinstance(purchase, dict):
        raise BuildError(f"purchase {purchase!r} is not a mapping")
    for kind in NAMED_KINDS:
        if kind in purchase:
            ap = purchase.get("ap")
            if not isinstance(ap, int) or ap < 0:
                raise BuildError(f"{kind} {purchase[kind]}: needs a non-negative integer ap")
            return {"kind": kind, "name": str(purchase[kind]), "ap": ap}
    if "raise" in purchase:
        target = str(purchase["raise"])
        start, end = purchase.get("from"), purchase.get("to")
        if not _valid_target(target):
            raise BuildError(f"raise {target}: unknown target")
        if not (isinstance(start, int) and isinstance(end, int) and end > start):
            raise BuildError(f"raise {target}: needs integers from < to")
        ap = raise_cost(start, end)
        if "ap" in purchase and purchase["ap"] != ap:
            raise BuildError(f"raise {target} {start}→{end} costs {ap} AP, file says {purchase['ap']}")
        return {"kind": "raise", "target": target, "from": start, "to": end, "ap": ap}
    if purchase.get("buy") == "lep":
        count = purchase.get("count")
        if not isinstance(count, int) or count < 1:
            raise BuildError("buy lep: needs a positive integer count")
        ap = lep_cost(count)
        if "ap" in purchase and purchase["ap"] != ap:
            raise BuildError(f"buy lep ×{count} costs {ap} AP, file says {purchase['ap']}")
        return {"kind": "buy", "target": "lep", "count": count, "ap": ap}
    raise BuildError(f"unknown purchase {purchase!r}")
