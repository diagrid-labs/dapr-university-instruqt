"""Extract and apply a dapr-workflow-aspire assignment's build-it-live steps.

The track has no upstream repo: every file the learner creates is pasted from a
``,copy`` fenced block or written by a ``bash,run`` (or ``shell,run``) block with a
quoted heredoc, and every command is a run block. This module parses those blocks
so the Robot suite can reconstruct the app exactly as the assignment describes,
catching drift in the tooling the assignment depends on.
"""
from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass

_FENCE_RE = re.compile(r"^```([^\n`]*)$")
_WRITABLE_LANGS = {"csharp", "json", "yaml", "xml"}
_RUN_LANGS = {"bash", "shell"}
# A heredoc opener (`<<EOF`, `<<'EOF'`, `<<"EOF"`, `<<-EOF`), not a here-string (`<<<`).
HEREDOC_RE = re.compile(r"(?<!<)<<(?!<)(-?)\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\2")


@dataclass(frozen=True)
class Block:
    lang: str              # first token of the info string, e.g. "shell", "csharp"
    tags: tuple[str, ...]  # remaining comma flags, e.g. ("run",), ("copy",)
    body: str              # block contents, fences stripped


def parse_blocks(md_text: str) -> list[Block]:
    blocks: list[Block] = []
    in_fence = False
    info = ""
    lines: list[str] = []
    for line in md_text.splitlines():
        fence = _FENCE_RE.match(line.strip())
        if fence is not None:
            if not in_fence:
                in_fence, info, lines = True, fence.group(1), []
            else:
                parts = [p.strip() for p in info.split(",") if p.strip()]
                lang = parts[0] if parts else ""
                blocks.append(Block(lang=lang, tags=tuple(parts[1:]), body="\n".join(lines)))
                in_fence = False
        elif in_fence:
            lines.append(line)
    return blocks


def is_run_block(b: Block) -> bool:
    return b.lang in _RUN_LANGS and "run" in b.tags


def is_writable_block(b: Block) -> bool:
    return b.lang in _WRITABLE_LANGS and "copy" in b.tags


def heredoc_end(line: str) -> tuple[str, bool] | None:
    """(terminator, strip_tabs) when the line opens a heredoc, else None."""
    m = HEREDOC_RE.search(line)
    return (m.group(3), m.group(1) == "-") if m else None


def command_lines(body: str) -> list[str]:
    """Logical command lines: join trailing-backslash continuations, drop blank
    and comment lines. A heredoc (`cat > f <<'EOF'` ... `EOF`) is one command
    whose body lines are kept verbatim (blank and `#` lines included)."""
    out: list[str] = []
    buf = ""
    raw_lines = body.splitlines()
    i = 0
    while i < len(raw_lines):
        raw = raw_lines[i]
        i += 1
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        heredoc = heredoc_end(line)
        if heredoc is not None:
            tag, strip_tabs = heredoc
            parts = [(buf + line).strip()]
            buf = ""
            while i < len(raw_lines):
                body_line = raw_lines[i]
                i += 1
                parts.append(body_line)
                if (body_line.lstrip("\t") if strip_tabs else body_line) == tag:
                    break
            out.append("\n".join(parts))
            continue
        if line.endswith("\\"):
            buf += line[:-1].rstrip() + " "
        else:
            out.append((buf + line).strip())
            buf = ""
    if buf.strip():
        out.append(buf.strip())
    return out


class UnmappedBlockError(Exception):
    """A writable block has no (or an ambiguous) manifest mapping."""


def dest_for_block(b: Block, manifest: list[tuple[str, str, str]]) -> tuple[str, str]:
    matches = [(anchor, dest, mode) for anchor, dest, mode in manifest if anchor in b.body]
    first_line = b.body.splitlines()[0] if b.body else "<empty>"
    if not matches:
        raise UnmappedBlockError(f"No manifest anchor matches a {b.lang} block; first line: {first_line!r}")
    if len(matches) > 1:
        raise UnmappedBlockError(f"Ambiguous: {[a for a, _, _ in matches]!r} all match one {b.lang} block")
    _, dest, mode = matches[0]
    return dest, mode


def resolve_files(blocks: list[Block], manifest: list[tuple[str, str, str]]) -> list[tuple[str, str, str]]:
    """Map every writable block to its destination. Raise if a block is unmapped
    or ambiguous, or if a manifest anchor matches no block."""
    resolved: list[tuple[str, str, str]] = []
    hits = {anchor: 0 for anchor, _, _ in manifest}
    for b in blocks:
        if not is_writable_block(b):
            continue
        dest, mode = dest_for_block(b, manifest)
        for anchor, d, m in manifest:
            if anchor in b.body:
                hits[anchor] += 1
        resolved.append((dest, mode, b.body))
    missing = [a for a, n in hits.items() if n == 0]
    if missing:
        raise UnmappedBlockError(f"Manifest anchors matched no block: {missing!r}")
    over = [a for a, n in hits.items() if n > 1]
    if over:
        raise UnmappedBlockError(f"Manifest anchors matched multiple blocks: {over!r}")
    return resolved


def _read(path: str) -> str:
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def _write(path: str, body: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(body if body.endswith("\n") else body + "\n")


def _resolve_cd(cwd: str, target: str) -> str:
    return target if os.path.isabs(target) else os.path.normpath(os.path.join(cwd, target))


def _run(command: str, cwd: str) -> None:
    result = subprocess.run(command, shell=True, cwd=cwd, capture_output=True, text=True, timeout=600)
    if result.returncode != 0:
        raise RuntimeError(
            f"Command failed (rc={result.returncode}) in {cwd}: {command}\n"
            f"{result.stdout}\n{result.stderr}"
        )


def _apply_block(solution_dir: str, dest: str, mode: str, body: str) -> None:
    path = os.path.join(solution_dir, dest)
    if mode == "write":
        _write(path, body)
    elif mode.startswith("insert_before:"):
        marker = mode.split(":", 1)[1]
        content = _read(path)
        if body.strip() in content:
            return  # idempotent
        snippet = body if body.endswith("\n") else body + "\n"
        _write(path, content.replace(marker, snippet + marker, 1))
    else:
        raise ValueError(f"Unknown manifest mode: {mode!r}")


class AssignmentBlocks:
    """Robot Framework library that reconstructs the aspire app from an assignment."""

    ROBOT_LIBRARY_SCOPE = "GLOBAL"
    ROBOT_AUTO_KEYWORDS = True  # RF: class name != module name, so mark this the library class

    def apply_challenge(self, assignment_path, start_dir, solution_dir,
                        files_manifest, skip_prefixes=("aspire run", "docker run"),
                        rewrite_from=None, rewrite_to=None):
        """Run the page's Run blocks and write its ,copy blocks, in page order. With rewrite_from
        and rewrite_to, every command has rewrite_from replaced by rewrite_to first, so a page that
        `cd`s to the VM's checkout (`/root/university-labs/...`) runs in the suite's checkout."""
        blocks = parse_blocks(_read(assignment_path))
        resolve_files(blocks, files_manifest)  # fail-loud coverage check up front
        cwd = start_dir
        for b in blocks:
            if is_run_block(b):
                for cmd in command_lines(b.body):
                    if rewrite_from:
                        cmd = cmd.replace(rewrite_from, rewrite_to)
                    if any(cmd.startswith(p) for p in skip_prefixes):
                        continue
                    if cmd.startswith("cd "):
                        cwd = _resolve_cd(cwd, cmd[3:].strip())
                        continue
                    _run(cmd, cwd)
            elif is_writable_block(b):
                dest, mode = dest_for_block(b, files_manifest)
                _apply_block(solution_dir, dest, mode, b.body)

    def get_command_containing(self, assignment_path, needle):
        for b in parse_blocks(_read(assignment_path)):
            if not is_run_block(b):
                continue
            for cmd in command_lines(b.body):
                if needle in cmd:
                    return cmd
        raise ValueError(f"No run command containing {needle!r} in {assignment_path}")

    def get_run_block_containing(self, assignment_path, needle):
        """The whole body of the first `bash,run` or `shell,run` block that contains needle, so a
        suite can run a multi-line block exactly as the page shows it."""
        for b in parse_blocks(_read(assignment_path)):
            if is_run_block(b) and needle in b.body:
                return b.body
        raise ValueError(f"No run block containing {needle!r} in {assignment_path}")
