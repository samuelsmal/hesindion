"""The rule vocabulary (specs/rules/vocabulary.json): the one contract between the YAML, rulec
and the Swift engine. Read-only; nothing here knows a rule by name."""

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
PATH = REPO / "specs" / "rules" / "vocabulary.json"


@dataclass(frozen=True)
class Vocabulary:
    raw: dict
    sha256: str

    @property
    def version(self) -> int:
        return self.raw["version"]

    @property
    def verbs(self) -> dict:
        return self.raw["verbs"]

    def fact_owner(self, name: str) -> str | None:
        if name in self.raw["facts"]:
            return self.raw["facts"][name]["owner"]
        for prefix, fam in self.raw["factFamilies"].items():
            if name.startswith(prefix) and len(name) > len(prefix):
                return fam["owner"]
        return None

    def is_target(self, name: str) -> bool:
        if name in self.raw["targets"]:
            return True
        return any(name.startswith(p) and name[len(p):] in self.raw["targets"]
                   for p in self.raw["targetPrefixes"])

    def target_contexts(self, name: str) -> list[str]:
        for p in [""] + self.raw["targetPrefixes"]:
            if name.startswith(p) and name[len(p):] in self.raw["targets"]:
                return self.raw["targets"][name[len(p):]]["contexts"]
        return []


def load(path: Path = PATH) -> Vocabulary:
    data = path.read_bytes()
    return Vocabulary(raw=json.loads(data), sha256=hashlib.sha256(data).hexdigest())
