# dapr-workflow-aspire Drift Tests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Robot Framework drift tests for the `dapr-workflow-aspire` track that reconstruct the build-it-live app by extracting the exact `,copy`/`,run` blocks from the assignments, build it, run it, and assert the workflow completes.

**Architecture:** A Python extraction library parses each `assignment.md` into fenced blocks, runs its `shell,run` commands (tracking `cd`), and writes its `,copy` file blocks to destinations mapped by a per-challenge manifest — raising on any unmapped writable block (fail-loud coverage). A single cumulative Robot suite drives four ordered checkpoints (ch2 scaffold+build → ch3 workflow build → ch4 apphost build → ch5 run+assert) in one working directory. A new CI workflow provisions .NET 10 + Aspire + Dapr and runs the suite.

**Tech Stack:** Robot Framework 7 (existing harness under `tools/track-tester/`), Python 3.12, pytest, .NET 10, Aspire CLI, Dapr CLI, Docker.

## Global Constraints

- **Harness location & run dir:** all `uv`/`robot`/`pytest` commands run from `tools/track-tester/`. Suite paths are written relative to that dir (`../../dapr-workflow-aspire/...`).
- **Track is build-it-live:** the app code lives ONLY in the assignments' `,copy` blocks. Never commit a copy of the app; always extract from `assignment.md`.
- **Fence tags:** this track uses `shell,run` / `shell,run,copy` (NOT `bash,run`) for commands, and `csharp,copy` / `json,copy` / `yaml,copy` / `xml,copy` (sometimes with `,wrap`) for file content. `,nocopy` blocks are display-only — never run or write them.
- **Cumulative challenges:** ch3 needs ch2's scaffold, ch4 needs ch3, ch5 runs the lot. One working directory, ordered test cases.
- **Single language:** .NET only. No dotnet/java/python tag matrix.
- **Pinned versions (drift-sensitive, do not "upgrade"):** `Dapr.Workflow 1.18.4`, `Dapr.Workflow.Versioning 1.18.4`, `CommunityToolkit.Aspire.Hosting.Dapr 13.0.0`; `dotnet new aspire-starter`.
- **Fixed runtime endpoints:** ApiService at `http://localhost:5411`; workflow started with `{"id":"mission-001","starDate":"41153.7"}`; status at `http://localhost:5411/status/mission-001`.
- **Do not run the diagrid-dashboard** (`docker run … diagrid-dashboard`) or ch2's `aspire run` verification step in the batch apply — the dashboard is read-only visualization and `aspire run` is launched explicitly (background) only in the ch5 checkpoint.
- **No changes** to `check_doc_sync.py`, the dapr-101/dapr-workflow suites, or the `dapr-workflow-aspire` assignment content.
- **Commit message trailer:** end each commit message with `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`.

---

## File Structure

**New files:**
- `tools/track-tester/libraries/assignment_blocks.py` — fence parser, block classification, file-mapping resolver (fail-loud), and the `AssignmentBlocks` Robot library (impure apply/get keywords).
- `tools/track-tester/libraries/tests/test_parse.py` — pytest for the pure parser/resolver functions.
- `tools/track-tester/libraries/tests/test_apply.py` — pytest for the impure apply logic against a synthetic assignment (no .NET needed).
- `tools/track-tester/libraries/tests/test_manifest.py` — pytest validating the real manifests against the real assignment files.
- `tools/track-tester/variables/dapr_workflow_aspire.py` — URLs, expected values, and the per-challenge block→file manifests.
- `dapr-workflow-aspire/tests/challenge.robot` — the cumulative suite.
- `tools/track-tester/ci/setup-dapr-workflow-aspire.sh` — CI sandbox reproduction (uv, Dapr, `dapr init`).
- `.github/workflows/test-dapr-workflow-aspire.yml` — CI workflow.

**Modified files:**
- `tools/track-tester/pyproject.toml` — add `libraries` and `variables` to pytest `pythonpath`/`testpaths`.

---

## Task 1: Pure extraction functions (parser + resolver)

**Files:**
- Create: `tools/track-tester/libraries/assignment_blocks.py`
- Create: `tools/track-tester/libraries/tests/test_parse.py`
- Modify: `tools/track-tester/pyproject.toml`

**Interfaces:**
- Produces:
  - `Block` dataclass: `lang: str`, `tags: tuple[str, ...]`, `body: str`.
  - `parse_blocks(md_text: str) -> list[Block]`
  - `is_run_block(b: Block) -> bool` (`lang == "shell" and "run" in tags`)
  - `is_writable_block(b: Block) -> bool` (`lang in {"csharp","json","yaml","xml"} and "copy" in tags`)
  - `command_lines(body: str) -> list[str]` (join `\`-continuations, drop blank/`#` lines)
  - `class UnmappedBlockError(Exception)`
  - `dest_for_block(b: Block, manifest: list[tuple[str,str,str]]) -> tuple[str,str]` → `(dest, mode)`; raises `UnmappedBlockError` on 0 or >1 anchor matches.
  - `resolve_files(blocks, manifest) -> list[tuple[str,str,str]]` → `[(dest, mode, body)]`; raises if any writable block is unmapped/ambiguous or any manifest anchor matches no block.

- [ ] **Step 1: Add pytest paths to pyproject.toml**

Modify `tools/track-tester/pyproject.toml`, replacing the `[tool.pytest.ini_options]` block:

```toml
[tool.pytest.ini_options]
pythonpath = ["docsync", "libraries", "variables"]
testpaths = ["docsync/tests", "libraries/tests"]
```

- [ ] **Step 2: Write the failing tests**

Create `tools/track-tester/libraries/tests/test_parse.py`:

```python
import pytest
from assignment_blocks import (
    Block,
    parse_blocks,
    is_run_block,
    is_writable_block,
    command_lines,
    dest_for_block,
    resolve_files,
    UnmappedBlockError,
)

MD = """
Intro.

```shell,run
dotnet new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics
```

```shell,run,copy
cd EnterpriseDiagnostics
```

```json,copy
{ "$schema": "https://json.schemastore.org/launchsettings.json" }
```

```text,nocopy
display only, ignored
```
"""


def test_parse_captures_lang_tags_body():
    blocks = parse_blocks(MD)
    assert [(b.lang, b.tags) for b in blocks] == [
        ("shell", ("run",)),
        ("shell", ("run", "copy")),
        ("json", ("copy",)),
        ("text", ("nocopy",)),
    ]
    assert blocks[0].body == "dotnet new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics"


def test_classification():
    blocks = parse_blocks(MD)
    assert [is_run_block(b) for b in blocks] == [True, True, False, False]
    assert [is_writable_block(b) for b in blocks] == [False, False, True, False]


def test_command_lines_joins_continuations_and_drops_comments():
    body = "# a comment\ndocker run -p 1:1 \\\n  -e X=y \\\n  image\n\ntouch f"
    assert command_lines(body) == ["docker run -p 1:1 -e X=y image", "touch f"]


def test_resolve_files_maps_by_anchor():
    blocks = parse_blocks(MD)
    manifest = [('"$schema": "https://json.schemastore.org/launchsettings.json"',
                 "AppHost/Properties/launchSettings.json", "write")]
    resolved = resolve_files(blocks, manifest)
    assert len(resolved) == 1
    dest, mode, body = resolved[0]
    assert dest == "AppHost/Properties/launchSettings.json"
    assert mode == "write"
    assert "$schema" in body


def test_resolve_files_raises_on_unmapped_block():
    blocks = parse_blocks("```csharp,copy\nclass Orphan {}\n```")
    with pytest.raises(UnmappedBlockError):
        resolve_files(blocks, [])


def test_resolve_files_raises_when_anchor_matches_nothing():
    blocks = parse_blocks(MD)
    manifest = [
        ('"$schema": "https://json.schemastore.org/launchsettings.json"',
         "AppHost/Properties/launchSettings.json", "write"),
        ("anchor that is absent", "nowhere.cs", "write"),
    ]
    with pytest.raises(UnmappedBlockError):
        resolve_files(blocks, manifest)
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `(cd tools/track-tester && uv run pytest libraries/tests/test_parse.py -v)`
Expected: FAIL — `ModuleNotFoundError: No module named 'assignment_blocks'`.

- [ ] **Step 4: Write the implementation**

Create `tools/track-tester/libraries/assignment_blocks.py`:

```python
"""Extract and apply a dapr-workflow-aspire assignment's build-it-live steps.

The track has no upstream repo: every file the learner creates is pasted from a
``,copy`` fenced block and every command is a ``shell,run`` block. This module
parses those blocks so the Robot suite can reconstruct the app exactly as the
assignment describes, catching drift in the tooling the assignment depends on.
"""
from __future__ import annotations

import os
import re
import subprocess
from dataclasses import dataclass

_FENCE_RE = re.compile(r"^```([^\n`]*)$")
_WRITABLE_LANGS = {"csharp", "json", "yaml", "xml"}


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
    return b.lang == "shell" and "run" in b.tags


def is_writable_block(b: Block) -> bool:
    return b.lang in _WRITABLE_LANGS and "copy" in b.tags


def command_lines(body: str) -> list[str]:
    """Logical command lines: join trailing-backslash continuations, drop blank
    and comment lines."""
    out: list[str] = []
    buf = ""
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.strip().startswith("#"):
            continue
        if line.endswith("\\"):
            buf += line[:-1] + " "
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
    return resolved
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `(cd tools/track-tester && uv run pytest libraries/tests/test_parse.py -v)`
Expected: PASS (6 passed).

- [ ] **Step 6: Commit**

```bash
git add tools/track-tester/libraries/assignment_blocks.py tools/track-tester/libraries/tests/test_parse.py tools/track-tester/pyproject.toml
git commit -m "test: add aspire assignment fence parser + file resolver

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 2: `AssignmentBlocks` Robot library (apply + get command)

**Files:**
- Modify: `tools/track-tester/libraries/assignment_blocks.py`
- Create: `tools/track-tester/libraries/tests/test_apply.py`

**Interfaces:**
- Consumes: `parse_blocks`, `is_run_block`, `is_writable_block`, `command_lines`, `dest_for_block`, `resolve_files` from Task 1.
- Produces (Robot keywords, class `AssignmentBlocks`):
  - `Apply Challenge  assignment_path  start_dir  solution_dir  files_manifest  [skip_prefixes]` — process blocks in document order: run each `shell,run` command line (skipping `cd` by mutating cwd, and skipping any command starting with a skip prefix), and write/insert each writable block per the manifest. Calls `resolve_files` up front so an unmapped block fails the test immediately. Default `skip_prefixes=("aspire run", "docker run")`.
  - `Get Command Containing  assignment_path  needle` → returns the first `shell,run` command line containing `needle` (raises `ValueError` if none). Used by ch5 to launch `aspire run` in the background and to run the `curl … /start` from the assignment text.

- [ ] **Step 1: Write the failing tests**

Create `tools/track-tester/libraries/tests/test_apply.py`:

```python
import os
import pytest
from assignment_blocks import AssignmentBlocks, UnmappedBlockError

SYNTH = """
```shell,run
mkdir sub
```

```csharp,copy
// ANCHOR-FOO
class Foo {}
```

```shell,run,copy
cd sub
```

```shell,run
touch made-in-sub.txt
```

```shell,run
aspire run
```
"""


def _write_md(tmp_path, text):
    p = tmp_path / "assignment.md"
    p.write_text(text)
    return str(p)


def test_apply_writes_files_runs_commands_tracks_cd_and_skips(tmp_path):
    md = _write_md(tmp_path, SYNTH)
    manifest = [("ANCHOR-FOO", "sub/Foo.cs", "write")]
    AssignmentBlocks().apply_challenge(md, str(tmp_path), str(tmp_path), manifest)
    # mkdir ran, file written under solution_dir
    assert (tmp_path / "sub" / "Foo.cs").read_text().strip().endswith("class Foo {}")
    # `cd sub` was honoured: touch created the file inside sub/
    assert (tmp_path / "sub" / "made-in-sub.txt").exists()
    # `aspire run` was skipped (no error, nothing to assert beyond no crash)


def test_apply_raises_on_unmapped_block(tmp_path):
    md = _write_md(tmp_path, "```csharp,copy\nclass Orphan {}\n```")
    with pytest.raises(UnmappedBlockError):
        AssignmentBlocks().apply_challenge(md, str(tmp_path), str(tmp_path), [])


def test_get_command_containing(tmp_path):
    md = _write_md(tmp_path, SYNTH)
    assert AssignmentBlocks().get_command_containing(md, "aspire run") == "aspire run"
    with pytest.raises(ValueError):
        AssignmentBlocks().get_command_containing(md, "no-such-command")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `(cd tools/track-tester && uv run pytest libraries/tests/test_apply.py -v)`
Expected: FAIL — `ImportError: cannot import name 'AssignmentBlocks'`.

- [ ] **Step 3: Append the implementation**

Append to `tools/track-tester/libraries/assignment_blocks.py`:

```python
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

    def apply_challenge(self, assignment_path, start_dir, solution_dir,
                        files_manifest, skip_prefixes=("aspire run", "docker run")):
        blocks = parse_blocks(_read(assignment_path))
        resolve_files(blocks, files_manifest)  # fail-loud coverage check up front
        cwd = start_dir
        for b in blocks:
            if is_run_block(b):
                for cmd in command_lines(b.body):
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `(cd tools/track-tester && uv run pytest libraries/tests/test_apply.py -v)`
Expected: PASS (3 passed).

- [ ] **Step 5: Commit**

```bash
git add tools/track-tester/libraries/assignment_blocks.py tools/track-tester/libraries/tests/test_apply.py
git commit -m "feat: add AssignmentBlocks Robot library (apply + get command)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 3: Variables + per-challenge manifests (validated against real assignments)

**Files:**
- Create: `tools/track-tester/variables/dapr_workflow_aspire.py`
- Create: `tools/track-tester/libraries/tests/test_manifest.py`

**Interfaces:**
- Consumes: `parse_blocks`, `resolve_files` from Task 1.
- Produces (module-level, imported by the suite via `Variables` and by the manifest test):
  - `APISERVICE_URL = "http://localhost:5411/"`
  - `STATUS_URL = "http://localhost:5411/status/mission-001"`
  - `EXPECTED_STARDATE = '"starDate":"41153.7"'`
  - `MANIFEST_CH2`, `MANIFEST_CH3`, `MANIFEST_CH4` — each a `list[tuple[anchor, dest, mode]]`.

- [ ] **Step 1: Write the failing test**

Create `tools/track-tester/libraries/tests/test_manifest.py`:

```python
import os
from assignment_blocks import parse_blocks, resolve_files
from dapr_workflow_aspire import MANIFEST_CH2, MANIFEST_CH3, MANIFEST_CH4

# libraries/tests/ -> tools/track-tester/libraries/tests -> repo root is 4 up.
_REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "..", ".."))


def _assignment(challenge):
    return os.path.join(_REPO, "dapr-workflow-aspire", challenge, "assignment.md")


def _resolve(challenge, manifest):
    with open(_assignment(challenge), encoding="utf-8") as fh:
        return resolve_files(parse_blocks(fh.read()), manifest)


def test_ch2_manifest_matches_real_assignment():
    assert len(_resolve("2-project-creation", MANIFEST_CH2)) == 1


def test_ch3_manifest_matches_real_assignment():
    assert len(_resolve("3-workflow-definition", MANIFEST_CH3)) == 6


def test_ch4_manifest_matches_real_assignment():
    assert len(_resolve("4-apphost-resources", MANIFEST_CH4)) == 4
```

- [ ] **Step 2: Run test to verify it fails**

Run: `(cd tools/track-tester && uv run pytest libraries/tests/test_manifest.py -v)`
Expected: FAIL — `ModuleNotFoundError: No module named 'dapr_workflow_aspire'`.

- [ ] **Step 3: Write the variables/manifest module**

Create `tools/track-tester/variables/dapr_workflow_aspire.py`:

```python
"""Variables and block->file manifests for the dapr-workflow-aspire suite.

Each manifest entry is (anchor, dest, mode):
  - anchor: a substring unique to the assignment's ,copy block body
  - dest:   path relative to the EnterpriseDiagnostics solution root
  - mode:   "write" (whole file) or "insert_before:<marker>" (splice into a file)
"""

APISERVICE_URL = "http://localhost:5411/"
STATUS_URL = "http://localhost:5411/status/mission-001"
EXPECTED_STARDATE = '"starDate":"41153.7"'

MANIFEST_CH2 = [
    (
        '"$schema": "https://json.schemastore.org/launchsettings.json"',
        "EnterpriseDiagnostics.AppHost/Properties/launchSettings.json",
        "write",
    ),
]

MANIFEST_CH3 = [
    ("class DiagnoseSubsystemActivity",
     "EnterpriseDiagnostics.ApiService/Activities/DiagnoseSubsystemActivity.cs", "write"),
    ("class NotifyBridgeActivity",
     "EnterpriseDiagnostics.ApiService/Activities/NotifyBridgeActivity.cs", "write"),
    ("class PrioritizeDiagnosticsActivity",
     "EnterpriseDiagnostics.ApiService/Activities/PrioritizeDiagnosticsActivity.cs", "write"),
    ("namespace EnterpriseDiagnostics.Models",
     "EnterpriseDiagnostics.ApiService/Models/Models.cs", "write"),
    ("class EnterpriseDiagnosticsWorkflow",
     "EnterpriseDiagnostics.ApiService/Workflows/EnterpriseDiagnosticsWorkflow.cs", "write"),
    ("builder.Services.AddDaprWorkflow",
     "EnterpriseDiagnostics.ApiService/Program.cs", "write"),
]

MANIFEST_CH4 = [
    ("name: workflow-state",
     "EnterpriseDiagnostics.AppHost/Resources/dapr/workflow-state.yaml", "write"),
    ("name: diagrid-dashboard-store",
     "EnterpriseDiagnostics.AppHost/Resources/dapr/diagrid-dashboard-components/diagrid-dashboard-state.yaml", "write"),
    ("<Content Include=\"Resources",
     "EnterpriseDiagnostics.AppHost/EnterpriseDiagnostics.AppHost.csproj", "insert_before:</Project>"),
    ("using CommunityToolkit.Aspire.Hosting.Dapr",
     "EnterpriseDiagnostics.AppHost/AppHost.cs", "write"),
]
```

- [ ] **Step 4: Run test to verify it passes**

Run: `(cd tools/track-tester && uv run pytest libraries/tests/test_manifest.py -v)`
Expected: PASS (3 passed). If a manifest test raises `UnmappedBlockError`, an anchor no longer matches its assignment block (real drift or a typo) — fix the anchor to match the assignment, do NOT edit the assignment.

- [ ] **Step 5: Run the full pytest suite**

Run: `(cd tools/track-tester && uv run pytest -v)`
Expected: PASS — the existing docsync tests plus the new parse/apply/manifest tests.

- [ ] **Step 6: Commit**

```bash
git add tools/track-tester/variables/dapr_workflow_aspire.py tools/track-tester/libraries/tests/test_manifest.py
git commit -m "feat: add aspire variables and per-challenge block manifests

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 4: The cumulative Robot suite

**Files:**
- Create: `dapr-workflow-aspire/tests/challenge.robot`

**Interfaces:**
- Consumes: `AssignmentBlocks` keywords (`Apply Challenge`, `Get Command Containing`) from Task 2; `APISERVICE_URL`, `STATUS_URL`, `EXPECTED_STARDATE`, `MANIFEST_CH2/3/4` from Task 3; `Start Background Process`, `Wait Until App Responds`, `Wait Until Command Output Contains`, `Run And Expect RC Zero`, `Stop Process With SIGINT` from the existing `resources/workflow.resource` + `resources/dapr.resource`.
- Produces: four ordered test cases sharing `${WORKDIR}` / `${SOLUTION_DIR}`.

- [ ] **Step 1: Write the suite**

Create `dapr-workflow-aspire/tests/challenge.robot`:

```robotframework
*** Settings ***
Name              Dapr Workflow Aspire
Documentation     Drift test for dapr-workflow-aspire: reconstruct the build-it-live
...               app from the assignments, build it, run it, assert the workflow completes.
Library           ../../tools/track-tester/libraries/assignment_blocks.py
Resource          ../../tools/track-tester/resources/workflow.resource
Variables         ../../tools/track-tester/variables/dapr_workflow_aspire.py
Suite Setup       Prepare Workdir
Suite Teardown    Terminate All Processes    kill=True

*** Variables ***
${WORKDIR}        ${TEMPDIR}${/}eds-track
${SOLUTION_DIR}   ${WORKDIR}${/}EnterpriseDiagnostics
${LOG}            ${TEMPDIR}/dapr-workflow-aspire.log
${ASSIGN_2}       ${CURDIR}/../2-project-creation/assignment.md
${ASSIGN_3}       ${CURDIR}/../3-workflow-definition/assignment.md
${ASSIGN_4}       ${CURDIR}/../4-apphost-resources/assignment.md
${ASSIGN_5}       ${CURDIR}/../5-run-application/assignment.md

*** Keywords ***
Prepare Workdir
    # Start from a clean working directory so reruns don't collide with a stale scaffold.
    Remove Directory    ${WORKDIR}    recursive=True
    Create Directory    ${WORKDIR}

*** Test Cases ***
Ch2 Scaffold And Build
    # Scaffold runs in ${WORKDIR}; the assignment's `cd EnterpriseDiagnostics`
    # moves into the solution. Writes launchSettings.json, adds the pinned NuGet
    # packages, and builds. `aspire run` is skipped (launched only in Ch5).
    Apply Challenge    ${ASSIGN_2}    ${WORKDIR}    ${SOLUTION_DIR}    ${MANIFEST_CH2}
    File Should Contain
    ...    ${SOLUTION_DIR}/EnterpriseDiagnostics.ApiService/EnterpriseDiagnostics.ApiService.csproj
    ...    Dapr.Workflow

Ch3 Workflow Build
    # Creates the Models/Workflows/Activities folders + files and rebuilds.
    Apply Challenge    ${ASSIGN_3}    ${SOLUTION_DIR}    ${SOLUTION_DIR}    ${MANIFEST_CH3}

Ch4 AppHost Build
    # Writes the two Dapr component files, splices the <Content> item group into the
    # AppHost csproj, replaces AppHost.cs, and rebuilds.
    Apply Challenge    ${ASSIGN_4}    ${SOLUTION_DIR}    ${SOLUTION_DIR}    ${MANIFEST_CH4}

Ch5 Run And Assert
    [Teardown]    Stop Process With SIGINT    app
    # Launch `aspire run` (from the assignment) in the background; it starts the
    # ApiService + its Dapr sidecar. Skip the diagrid-dashboard docker step.
    ${aspire}=    Get Command Containing    ${ASSIGN_5}    aspire run
    Start Background Process    ${aspire}    ${LOG}    app    cwd=${SOLUTION_DIR}
    Wait Until App Responds    ${APISERVICE_URL}    timeout=240s
    # Start the workflow with the assignment's exact curl, then poll until the
    # output echoes the input stardate (present only once the workflow completes).
    ${start}=    Get Command Containing    ${ASSIGN_5}    /start
    Run And Expect RC Zero    ${start}
    Wait Until Command Output Contains    curl -s ${STATUS_URL}    ${EXPECTED_STARDATE}    timeout=120s
```

- [ ] **Step 2: Validate the suite resolves (no runtime env needed)**

Run: `(cd tools/track-tester && uv run robot --dryrun ../../dapr-workflow-aspire/tests/challenge.robot)`
Expected: PASS — all keywords/variables/imports resolve (`4 tests, 4 passed` in dry-run).

- [ ] **Step 3: Full run (requires .NET 10 + Aspire CLI + templates + Docker + `dapr init`)**

> Only run this where the runtime is available (locally with the stack installed, or in CI via Task 6). If your machine lacks .NET 10 / Aspire, skip to the commit — CI is the authoritative gate for the full run (mirrors the note in `MEMORY.md` about the .NET runtime being an environment concern, not a track bug).

Run: `(cd tools/track-tester && uv run robot --outputdir results/aspire ../../dapr-workflow-aspire/tests/challenge.robot)`
Expected: PASS — `4 tests, 4 passed`. Open `results/aspire/log.html` on failure.

Two things to confirm here and adjust if needed (see spec "Deferred to implementation"):
  1. **Readiness / completion.** If `/status/mission-001` never shows `"starDate":"41153.7"`, inspect the raw response (`curl -s http://localhost:5411/status/mission-001`) — the completion signal may be a `state` runtime-status field instead; update `EXPECTED_STARDATE` / the poll accordingly. If the app is slow to bind `:5411`, raise the `Wait Until App Responds` timeout.
  2. **Aspire startup.** If `aspire run` fails because the ApiService port isn't `5411`, re-check that ch4's `AppHost.cs` `WithHttpEndpoint(port: 5411, ...)` was applied.

- [ ] **Step 4: Commit**

```bash
git add dapr-workflow-aspire/tests/challenge.robot
git commit -m "feat: add cumulative Robot suite for dapr-workflow-aspire

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 5: CI sandbox setup script

**Files:**
- Create: `tools/track-tester/ci/setup-dapr-workflow-aspire.sh`

**Interfaces:**
- Produces: an executable script that installs `uv`, the Dapr CLI, and runs `dapr init` (providing the `dapr_redis` state store the workflow uses). .NET 10, the Aspire CLI, and the Aspire templates are provisioned by the CI workflow's own steps (Task 6), not here. No diagrid-dashboard pull.

- [ ] **Step 1: Write the script**

Create `tools/track-tester/ci/setup-dapr-workflow-aspire.sh`:

```bash
#!/usr/bin/env bash
# Reproduce the dapr-workflow-aspire sandbox environment in CI.
# The track builds the app live from the assignments, so there is no repo to
# clone. This script provisions the runtime bits the suite needs at test time:
# uv (to run robot), the Dapr CLI, and `dapr init` (the workflow state store
# points at the dapr_redis container it starts). .NET 10 + the Aspire CLI and
# project templates are installed by the workflow's own steps. The diagrid
# dashboard is NOT pulled — the suite does not run it.
set -euo pipefail

# 1. Install uv (used to run robot).
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  echo "$HOME/.local/bin" >> "${GITHUB_PATH:-/dev/null}"
fi

# 2. Install the Dapr CLI from master (matching the track's _setup, which does
#    not pin a version) and initialise Dapr (starts dapr_redis etc.).
if ! command -v dapr >/dev/null 2>&1; then
  curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | /bin/bash
fi
dapr uninstall --all >/dev/null || true
dapr init

echo "Setup complete."
```

- [ ] **Step 2: Verify the script is syntactically valid**

Run: `bash -n tools/track-tester/ci/setup-dapr-workflow-aspire.sh && echo OK`
Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add tools/track-tester/ci/setup-dapr-workflow-aspire.sh
git commit -m "ci: add dapr-workflow-aspire sandbox setup script

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Task 6: CI workflow

**Files:**
- Create: `.github/workflows/test-dapr-workflow-aspire.yml`

**Interfaces:**
- Consumes: `tools/track-tester/ci/setup-dapr-workflow-aspire.sh` (Task 5); the suite `dapr-workflow-aspire/tests/challenge.robot` (Task 4).
- Produces: a `build-and-run` job (single language) and a `report` job that opens/updates a `drift-report` issue on scheduled failure.

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/test-dapr-workflow-aspire.yml`:

```yaml
name: Test dapr-workflow-aspire track

on:
  schedule:
    - cron: '30 6 * * 2'   # Tuesdays 06:30 UTC (offset from dapr-workflow's Monday run)
  workflow_dispatch:
  pull_request:
    paths:
      - 'dapr-workflow-aspire/**'
      - 'tools/track-tester/**'
      - '.github/workflows/test-dapr-workflow-aspire.yml'

permissions:
  contents: read
  issues: write

jobs:
  build-and-run:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: astral-sh/setup-uv@v5
      - name: Set up .NET 10
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '10.0.x'
      - name: Install Aspire CLI
        run: |
          curl -sSL https://aspire.dev/install.sh | bash
          # The installer prints the install dir; add the common location to PATH.
          echo "$HOME/.aspire/bin" >> "$GITHUB_PATH"
      - name: Install Aspire project templates
        # Provides `dotnet new aspire-starter`. If drift makes the scaffold fail,
        # pin the version here to match the sandbox image (see spec deferred item).
        run: dotnet new install Aspire.ProjectTemplates
      - name: Setup Dapr sandbox
        run: bash tools/track-tester/ci/setup-dapr-workflow-aspire.sh
      - name: Sync harness
        run: (cd tools/track-tester && uv sync)
      - name: Run aspire track suite
        run: |
          cd tools/track-tester
          mkdir -p results
          uv run robot --outputdir results --name "dapr-workflow-aspire" \
            ../../dapr-workflow-aspire/tests/challenge.robot
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: robot-aspire
          path: tools/track-tester/results/

  report:
    needs: [build-and-run]
    if: failure()
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const title = 'Dapr Workflow Aspire track drift detected';
            const runUrl = `${context.serverUrl}/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`;
            const body = [
              `The dapr-workflow-aspire drift test **failed**.`,
              ``,
              `- Run: ${runUrl}`,
              `- Download the \`robot-aspire\` artifact and open \`report.html\` / \`log.html\` for the failing checkpoint.`,
              ``,
              `_This issue is updated automatically each run._`,
            ].join('\n');
            const existing = await github.rest.issues.listForRepo({
              owner: context.repo.owner, repo: context.repo.repo,
              state: 'open', labels: 'drift-report',
            });
            const match = existing.data.find(i => i.title === title);
            if (match) {
              await github.rest.issues.createComment({
                owner: context.repo.owner, repo: context.repo.repo,
                issue_number: match.number, body,
              });
            } else {
              await github.rest.issues.create({
                owner: context.repo.owner, repo: context.repo.repo,
                title, body, labels: ['drift-report'],
              });
            }
```

- [ ] **Step 2: Validate the workflow YAML**

Run: `(cd tools/track-tester && uv run python -c "import yaml,sys; yaml.safe_load(open('../../.github/workflows/test-dapr-workflow-aspire.yml')); print('OK')")`
Expected: `OK`. (If PyYAML is unavailable, use any local YAML linter; the file must parse.)

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/test-dapr-workflow-aspire.yml
git commit -m "ci: add dapr-workflow-aspire drift test workflow

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 4: Push the branch and open a PR to trigger the workflow**

Because the full suite needs .NET 10 + Aspire + Docker, CI is the authoritative gate. Open a PR (the `pull_request` paths filter matches `dapr-workflow-aspire/**` and `tools/track-tester/**`) and confirm the `build-and-run` job goes green. Resolve the two deferred items (Aspire CLI PATH, `aspire run`/`/status` behavior) against the real CI run, editing Task 4's suite and Task 6's Aspire steps as needed, then re-push.

---

## Self-Review

**Spec coverage:**
- Extract-from-assignment source model → Tasks 1–2 (parser + apply). ✓
- Single cumulative suite, four checkpoints → Task 4. ✓
- Full workflow run in ch5, skip dashboard → Task 4 (skip prefixes + orchestrated `aspire run`/curl). ✓
- Manifest by content anchor → Task 3. ✓
- Fail-loud coverage (no separate static checker; `check_doc_sync.py` untouched) → `resolve_files` in Task 1, enforced in `apply_challenge` Task 2, plus manifest pytest Task 3. ✓
- `.csproj` `<Content>` insertion + NuGet adds → `insert_before` mode (Task 2/3) + run-blocks. ✓
- CI setup script (uv, Dapr, `dapr init`, no dashboard) → Task 5. ✓
- Single-job CI workflow + drift-report issue → Task 6. ✓
- Deferred items (aspire readiness/`/status` shape, template provisioning, csproj mechanism) → surfaced in Task 4 Step 3 and Task 6 (csproj resolved concretely via `insert_before`). ✓
- Non-goals (no assignment edits, no doc-sync change, .NET only, no ch1 suite) → honored throughout. ✓

**Placeholder scan:** No "TBD/TODO"; every code step shows complete code; deferred items carry concrete starting commands + explicit verification, not blanks.

**Type consistency:** `Block(lang, tags, body)`, `dest_for_block → (dest, mode)`, `resolve_files → [(dest, mode, body)]`, manifest entries are 3-tuples `(anchor, dest, mode)` everywhere (Tasks 1/2/3), `apply_challenge`/`get_command_containing` keyword names match between Task 2, Task 4, and the interface blocks. Consistent.
