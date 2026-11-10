"""Read a version pin from an HCL file.

A pin is the `default` of a `variable "<name>" { ... }` block. Stdlib only so
bash CI scripts can call it with a bare `python3`.

CLI: read_pin.py <file.hcl> <name>  -> prints the value; errors go to stderr, exit 1.
"""

import re
import sys

_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_COMMENT_LINE = re.compile(r"^\s*(#|//).*$", re.MULTILINE)
_DEFAULT = re.compile(r'^\s*default\s*=\s*"([^"]*)"', re.MULTILINE)


def _top_level_body(text: str, start: int) -> str:
    """Return the depth-1 content of the block whose body begins at `start`.

    Braces inside double-quoted strings are ignored; nested blocks are dropped.
    """
    depth = 1
    in_string = False
    out = []
    i = start
    while i < len(text):
        ch = text[i]
        if in_string:
            if ch == "\\":
                if depth == 1:
                    out.append(text[i : i + 2])
                i += 2
                continue
            if ch == '"':
                in_string = False
        elif ch == '"':
            in_string = True
        elif ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                return "".join(out)
        if depth == 1:
            out.append(ch)
        i += 1
    raise ValueError("unterminated block")


def read_pin(path: str, name: str) -> str:
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    text = _COMMENT_LINE.sub("", _BLOCK_COMMENT.sub("", text))
    header = re.compile(r'variable\s+"' + re.escape(name) + r'"\s*\{')
    bodies = [_top_level_body(text, m.end()) for m in header.finditer(text)]
    if not bodies:
        raise LookupError(f"pin '{name}' not found in {path}")
    if len(bodies) > 1:
        raise LookupError(f"pin '{name}' defined more than once in {path}")
    match = _DEFAULT.search(bodies[0])
    if not match:
        raise LookupError(f"pin '{name}' has no default in {path}")
    return match.group(1)


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: read_pin.py <file.hcl> <name>", file=sys.stderr)
        return 2
    try:
        print(read_pin(argv[1], argv[2]))
    except (LookupError, ValueError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
