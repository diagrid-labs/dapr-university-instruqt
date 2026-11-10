"""Read a version pin from an HCL file.

A pin is the `default` of a `variable "<name>" { ... }` block. Stdlib only so
bash CI scripts can call it with a bare `python3`.

CLI: read_pin.py <file.hcl> <name>  -> prints the value; errors go to stderr, exit 1.
"""

import re
import sys

_COMMENT_LINE = re.compile(r"^\s*(#|//).*$", re.MULTILINE)
_DEFAULT = re.compile(r'\bdefault\s*=\s*"([^"]*)"')


def read_pin(path: str, name: str) -> str:
    with open(path, encoding="utf-8") as fh:
        text = _COMMENT_LINE.sub("", fh.read())
    block = re.compile(r'variable\s+"' + re.escape(name) + r'"\s*\{(.*?)\}', re.DOTALL)
    blocks = block.findall(text)
    if not blocks:
        raise LookupError(f"pin '{name}' not found in {path}")
    if len(blocks) > 1:
        raise LookupError(f"pin '{name}' defined more than once in {path}")
    match = _DEFAULT.search(blocks[0])
    if not match:
        raise LookupError(f"pin '{name}' not found in {path}")
    return match.group(1)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: read_pin.py <file.hcl> <name>", file=sys.stderr)
        return 2
    try:
        print(read_pin(argv[1], argv[2]))
    except (LookupError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
