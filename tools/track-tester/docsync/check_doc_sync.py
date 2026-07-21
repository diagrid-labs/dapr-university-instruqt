"""Assert that every runnable command in an assignment.md is covered by its Robot suite."""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass

LANG_BY_SUMMARY = {
    ".NET": "dotnet",
    "Python": "python",
    "Java": "java",
    "JavaScript": "javascript",
}

_FENCE_RE = re.compile(r"^```([^\n`]*)$")
_SUMMARY_RE = re.compile(r"<summary>(.*?)</summary>", re.IGNORECASE | re.DOTALL)


@dataclass(frozen=True)
class Command:
    text: str
    lang: str | None


def _is_run_fence(info: str) -> bool:
    parts = [p.strip() for p in info.split(",")]
    return bool(parts) and parts[0] == "bash" and "run" in parts


def _lang_from_summary(line: str) -> str | None:
    m = _SUMMARY_RE.search(line)
    if not m:
        return None
    # Longest key first so "JavaScript" wins over "Java".
    for key in sorted(LANG_BY_SUMMARY, key=len, reverse=True):
        if key in m.group(1):
            return LANG_BY_SUMMARY[key]
    return None


def extract_run_commands(md_text: str) -> list[Command]:
    commands: list[Command] = []
    current_lang: str | None = None
    in_fence = False
    fence_is_run = False
    for line in md_text.splitlines():
        stripped = line.strip()
        fence = _FENCE_RE.match(stripped)
        if fence is not None:
            if not in_fence:
                in_fence = True
                fence_is_run = _is_run_fence(fence.group(1))
            else:
                in_fence = False
                fence_is_run = False
            continue
        if in_fence:
            if fence_is_run and stripped and not stripped.startswith("#"):
                commands.append(Command(text=stripped, lang=current_lang))
            continue
        # Outside fences: track <details> language scope.
        lang = _lang_from_summary(line)
        if lang is not None:
            current_lang = lang
        elif "</details>" in stripped.lower():
            current_lang = None
    return commands


def normalize(text: str) -> str:
    return " ".join(text.split())


def find_uncovered(commands: list[Command], haystack: str) -> list[Command]:
    normalized_haystack = normalize(haystack)
    return [c for c in commands if normalize(c.text) not in normalized_haystack]


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    if len(argv) < 2:
        print("usage: check_doc_sync.py <assignment.md> <suite.robot> [more_files...]",
              file=sys.stderr)
        return 2
    assignment_path, *coverage_paths = argv
    try:
        md_text = _read(assignment_path)
        haystack = "\n".join(_read(p) for p in coverage_paths)
    except OSError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    commands = extract_run_commands(md_text)
    uncovered = find_uncovered(commands, haystack)
    if uncovered:
        print(f"DRIFT: {len(uncovered)} assignment command(s) not covered in {assignment_path}:")
        for c in uncovered:
            label = c.lang or "all"
            print(f"  [{label}] {c.text}")
        return 1
    print(f"OK: all {len(commands)} runnable command(s) covered ({assignment_path}).")
    return 0


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


if __name__ == "__main__":
    raise SystemExit(main())
