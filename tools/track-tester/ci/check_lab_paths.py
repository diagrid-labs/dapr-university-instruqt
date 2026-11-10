"""Check that files referenced from a lab/module's HCL exist.

`instruqt lab validate` does not verify `file("...")` targets or the `script = "..."` /
`file = "..."` attributes, so a typo only surfaces at import time. This scans *.hcl in a
directory (recursively) and fails listing every referenced path that does not exist
relative to that directory. Stdlib only.

CLI: check_lab_paths.py <dir>  -> exit 0 if all exist, 1 (with a list on stderr) otherwise.
"""

import re
import sys
from pathlib import Path

_BLOCK_COMMENT = re.compile(r"/\*.*?\*/", re.DOTALL)
_COMMENT_LINE = re.compile(r"^\s*(#|//).*$", re.MULTILINE)
# `file("x")`, but not an escaped `file(\"x\")` inside a description string.
_FILE_CALL = re.compile(r'(?<![\w.])file\(\s*"([^"\\]+)"\s*\)')
# `script = "x"` / `file = "x"` attributes (not `startup_script = ...`).
_ATTR = re.compile(r'^\s*(?:script|file)\s*=\s*"([^"\\]+)"', re.MULTILINE)


def referenced_paths(text: str) -> list[str]:
    text = _BLOCK_COMMENT.sub("", text)
    text = _COMMENT_LINE.sub("", text)
    return _FILE_CALL.findall(text) + _ATTR.findall(text)


def missing_paths(root: Path) -> list[tuple[str, str]]:
    """Return (hcl file, referenced path) pairs whose target does not exist under root."""
    missing = []
    for hcl in sorted(root.rglob("*.hcl")):
        for ref in referenced_paths(hcl.read_text()):
            if not (root / ref).is_file():
                missing.append((str(hcl.relative_to(root)), ref))
    return missing


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: check_lab_paths.py <dir>", file=sys.stderr)
        return 2
    root = Path(argv[1])
    if not root.is_dir():
        print(f"check_lab_paths: not a directory: {root}", file=sys.stderr)
        return 2
    missing = missing_paths(root)
    for hcl, ref in missing:
        print(f"ERROR: {hcl} references missing file: {ref}", file=sys.stderr)
    return 1 if missing else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
