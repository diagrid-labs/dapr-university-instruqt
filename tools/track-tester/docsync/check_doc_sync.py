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
    "TypeScript": "typescript",
}

_FENCE_RE = re.compile(r"^```([^\n`]*)$")
_SUMMARY_RE = re.compile(r"<summary>(.*?)</summary>", re.IGNORECASE | re.DOTALL)
# A heredoc opener (`<<EOF`, `<<'EOF'`, `<<"EOF"`, `<<-EOF`), not a here-string (`<<<`).
_HEREDOC_RE = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")


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
    # An open heredoc in a Run block: (terminator, strip leading tabs, lines so far). The whole
    # heredoc, opener to terminator, is ONE command with its body kept verbatim (blank lines and
    # `#` lines such as `#:package ...` included), so its body is never matched line by line.
    heredoc: tuple[str, bool, list[str]] | None = None
    for line in md_text.splitlines():
        stripped = line.strip()
        if heredoc is not None and _FENCE_RE.match(stripped) is not None:
            # A heredoc without its terminator ends with its block.
            commands.append(Command(text="\n".join(heredoc[2]), lang=current_lang))
            heredoc = None
        if heredoc is not None:
            tag, strip_tabs, parts = heredoc
            parts.append(line)
            if (line.lstrip("\t") if strip_tabs else line) == tag:
                commands.append(Command(text="\n".join(parts), lang=current_lang))
                heredoc = None
            continue
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
                m = _HEREDOC_RE.search(stripped)
                if m is not None:
                    heredoc = (m.group(3), m.group(1) == "-", [stripped])
                else:
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


def uncomment(text: str) -> str:
    """Each line without one leading `#`, so a multi-line command listed in a suite's
    `# doc-sync coverage` comment block (`#   <line>` per line) reads as the command again."""
    return "\n".join(re.sub(r"^\s*#", "", line, count=1) for line in text.splitlines())


def find_uncovered(commands: list[Command], haystack: str) -> list[Command]:
    normalized_haystack = normalize(haystack)
    uncommented_haystack: str | None = None
    uncovered = []
    for c in commands:
        text = normalize(c.text)
        if text in normalized_haystack:
            continue
        # Only a multi-line command (a heredoc) may match the uncommented suite: single-line
        # commands keep the plain substring check they always had.
        if "\n" in c.text:
            if uncommented_haystack is None:
                uncommented_haystack = normalize(uncomment(haystack))
            if text in uncommented_haystack:
                continue
        uncovered.append(c)
    return uncovered


# A `cd` at the start of a command or after `&&`, `||` or `;`, and its target.
_CD_RE = re.compile(r"(?:^|&&|\|\||;)\s*cd(?:\s+(\S+))?")


def find_unanchored_cds(commands: list[Command]) -> list[Command]:
    """Commands that `cd` to a relative path before any absolute `cd` on the page.

    In an Instruqt 2.0 lab the terminals keep their folder across pages, so a page cannot assume
    its terminal starts in the lab folder. A relative `cd` is safe once the page has first gone
    to an absolute path (the lab folder). A target that starts with `/`, `~` or `$`, or a bare
    `cd`, counts as absolute.
    """
    unanchored = []
    anchored = False
    for c in commands:
        for m in _CD_RE.finditer(c.text):
            target = m.group(1)
            if target is None or target.startswith(("/", "~", "$")):
                anchored = True
            elif not anchored:
                unanchored.append(c)
                break
    return unanchored


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    require_anchored_cd = "--require-anchored-cd" in argv
    argv = [a for a in argv if a != "--require-anchored-cd"]
    if len(argv) < 2:
        print("usage: check_doc_sync.py [--require-anchored-cd] <assignment.md> <suite.robot>"
              " [more_files...]", file=sys.stderr)
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
    unanchored_cds = find_unanchored_cds(commands) if require_anchored_cd else []
    if uncovered:
        print(f"DRIFT: {len(uncovered)} assignment command(s) not covered in {assignment_path}:")
        for c in uncovered:
            label = c.lang or "all"
            print(f"  [{label}] {c.text}")
    if unanchored_cds:
        print(f"UNANCHORED CD: {len(unanchored_cds)} command(s) in {assignment_path} change to a"
              " relative folder before the page has gone to the lab folder. Terminals keep their"
              " folder across pages, so first add a Run block that goes to the lab folder with"
              " an absolute path (for example `cd /root/<repo>/<folder>`):")
        for c in unanchored_cds:
            label = c.lang or "all"
            print(f"  [{label}] {c.text}")
    if uncovered or unanchored_cds:
        return 1
    print(f"OK: all {len(commands)} runnable command(s) covered ({assignment_path}).")
    return 0


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


if __name__ == "__main__":
    raise SystemExit(main())
