"""An Optolith hero file resolved into what a situation states about the hero: the rules it owns
(`owned`, from `activatable`) and the sheet's facts (attributes, combat techniques, talents)."""
import json
from pathlib import Path

ATTR = {"ATTR_1": "MU", "ATTR_2": "KL", "ATTR_3": "IN", "ATTR_4": "CH",
        "ATTR_5": "FF", "ATTR_6": "GE", "ATTR_7": "KO", "ATTR_8": "KK"}


def from_optolith(path: Path) -> dict:
    d = json.loads(Path(path).read_text(encoding="utf-8"))
    owned = {}
    for rid, entries in (d.get("activatable") or {}).items():
        if not entries:
            continue
        e = entries[0]
        owned[rid] = {"level": e.get("tier", 1)}
        if "sid" in e:
            owned[rid]["option"] = e["sid"]
        if "sid2" in e:                               # a second select option: SA_9's Anwendungsgebiet
            owned[rid]["option2"] = e["sid2"]
    facts = [{"name": f"attr.{ATTR[a['id']]}", "value": a["value"], "owner": "sheet"}
             for a in d["attr"]["values"]]
    facts += [{"name": f"ktw.{k}", "value": v, "owner": "sheet"} for k, v in sorted(d.get("ct", {}).items())]
    facts += [{"name": f"fw.{k}", "value": v, "owner": "sheet"} for k, v in sorted(d.get("talents", {}).items())]
    return {"id": d["id"], "owned": owned, "facts": facts}
