"""PyYAML's SafeLoader, but every mapping remembers the 1-based line of each of its keys, so
rulec can name the line of any error."""
import yaml


class LineDict(dict):
    line: int = 0
    key_lines: dict

    def __init__(self, *a, **kw):
        super().__init__(*a, **kw)
        self.key_lines = {}


class _Loader(yaml.SafeLoader):
    pass


def _construct_mapping(loader, node, deep=False):
    loader.flatten_mapping(node)
    m = LineDict()
    m.line = node.start_mark.line + 1
    for k_node, v_node in node.value:
        k = loader.construct_object(k_node, deep=deep)
        m[k] = loader.construct_object(v_node, deep=deep)
        m.key_lines[k] = k_node.start_mark.line + 1
    return m


_Loader.add_constructor(yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, _construct_mapping)


def loads(text: str, name: str):
    return yaml.load(text, Loader=_Loader)


def load(path):
    return loads(path.read_text(encoding="utf-8"), str(path))


def line_of(mapping, key) -> int | None:
    return getattr(mapping, "key_lines", {}).get(key)
