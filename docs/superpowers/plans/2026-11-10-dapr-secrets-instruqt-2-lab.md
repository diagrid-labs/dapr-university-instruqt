# Dapr Secrets Instruqt 2.0 Lab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `dapr-secrets` as an Instruqt 2.0 lab deployed from this repo by git push, built on a new shared `diagrid/dapr-sandbox` module, with CI validating everything and a runbook for the Instruqt-side steps.

**Architecture:** The `dapr-secrets/` folder becomes a 2.0 lab root: HCL files at its top level, pages pointing at the existing `N-slug/assignment.md` files. A new `modules/dapr-sandbox/` module owns the VM and its toolchain (custom Image Builder image, built by hand from a script rendered out of the repo). Lab launch runs one idempotent `lab-setup.sh` on the VM; the Vault start/seed logic moves to one script shared by the lab and CI. Every pin is read by one small parser, so it lives in exactly one HCL file.

**Tech Stack:** Instruqt 2.0 HCL + CLI (`instruqt lab fmt|validate`), bash, Python 3.12 stdlib (pin parser) + pytest, Robot Framework (existing suites), GitHub Actions.

**Spec:** `docs/superpowers/specs/2026-11-10-dapr-secrets-instruqt-2-lab-design.md`

## Global Constraints

- Instruqt team slug: `diagrid`. Module address: `diagrid/dapr-sandbox`. Lab test address: `diagrid/dapr-secrets`.
- Lab is imported with branch `main`, root directory `dapr-secrets`. All changes reach `main` via PR.
- Learner wait from start to usable first page: **≤ 1 minute 30 seconds**.
- Toolchain: Docker Engine, .NET SDK 10.0, Python 3.12 (distro) + uv on the default `PATH` (`/usr/local/bin`), JDK 17 + Maven, Node.js 24 LTS + npm, Dapr CLI 1.18.2. Base: Instruqt `ubuntu:24.04`, `x86_64`.
- Dapr runtime pin: 1.18.7. Vault image: `hashicorp/vault:1.20`, dev mode, root token `root`, port 8200, secrets at `secret/dapr/<name>`.
- Demo repo: `diagrid-labs/ai-agent-tracks-instruqt`, cloned to `~/ai-agent-tracks-instruqt` (path is relied on by assignments, tabs and tests).
- Pins: toolchain + image ref in `modules/dapr-sandbox/versions.hcl`; module version (exact, no range), `dapr_runtime_version`, `tracks_src_ref` in `dapr-secrets/versions.hcl`. No pin may appear in a second file.
- No credential may be readable from a learner terminal (no Docker Hub PAT in VM `environment`).
- Time limit 30 min, idle timeout 10 min, extra time 10 min.
- Keep `bash,run` / `yaml,copy` / `nocopy` / `wrap` fence annotations and the `# doc-sync coverage` blocks intact.
- Never simplify `Stop Process With SIGINT` in `tools/track-tester/resources/dapr.resource`.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **`instruqt lab fmt` realigns `=` signs and re-indents.** The pin parser must still read a pin after fmt pads it to `name    = "x"` or puts it inside a nested block. Test in Task 2.
2. **A missing or duplicated pin must fail loudly**, not yield an empty version that makes `dapr init --runtime-version ""` silently install latest. Test in Task 2, and `lab-setup.sh` must refuse empty env vars (Task 4).
3. **Lab setup re-run on a relaunched/restarted VM** (startup scripts run at every boot): must not re-clone over a learner's edits, re-`dapr init` running containers, or fail because Vault already exists. Test in Task 4.
4. **Path-filtered required checks**: a PR that touches only another track must not be blocked forever by a required dapr-secrets check that never runs. Test in Task 7.
5. **Learner starts on page 3 or 4 directly** (jump ahead): everything the page needs must already exist from lab-level setup, since per-challenge `setup.sh` goes away. Covered by the background pre-build in Task 4 and the play-through in Task 10.

---

## File Structure

```
modules/dapr-sandbox/
  main.hcl                    variables (cpu, memory, lab_startup_script, lab_environment), vm resource, outputs
  versions.hcl                toolchain + image pins (variable blocks with defaults)
  scripts/install-tools.sh    installs the toolchain; reads versions from env, fails if any is unset
  scripts/prewarm.sh          warms NuGet/Maven/uv caches + pre-pulls container images
  scripts/render-image-script.sh  prints one self-contained script for the Image Builder
  README.md
dapr-secrets/
  versions.hcl                lab pins + the module block
  main.hcl                    resource "lab"
  layouts.hcl, tabs.hcl, pages.hcl, tasks.hcl
  scripts/lab-setup.sh        runs on the VM at boot
  scripts/seed-vault.sh       start + seed Vault (shared with CI)
  3-secret-scoping/scripts/check-*.sh, solve.sh
  4-swap-the-provider/scripts/check-*.sh, solve.sh
tools/track-tester/ci/read_pin.py         pin parser (CLI + importable)
tools/track-tester/ci/tests/test_read_pin.py
docs/instruqt-2-spike-checklist.md
docs/instruqt-2-runbook.md
```

Removed after acceptance (Task 11): `dapr-secrets/_setup/`, `dapr-secrets/*/tabs.md`, `dapr-secrets/*/README.md` (challenge-level), `dapr-secrets/*/scripts/setup.sh`, `dapr-secrets/*/scripts/check.sh`.

---

### Task 1: Instruqt CLI, real schema, and the spike checklist

Everything later is written against the real HCL schema, so this task establishes it.

**Files:**
- Create: `docs/instruqt-2-spike-checklist.md`

**Interfaces:**
- Produces: the installed CLI version (recorded at the top of the checklist as `Instruqt CLI version: <x>`; Task 7 pins CI to it), and answers recorded in the checklist's "Schema facts" section that Tasks 3–6 follow: does a lab accept `variable` blocks with `default`; does `startup_script` accept `file("...")`; does `module` accept a local `source = "../modules/dapr-sandbox"` outside the lab root; what the editor tab resource type is called; whether `lab validate` accepts a module directory.

- [ ] **Step 1:** `brew install instruqt/tap/instruqt`, then `instruqt version`. Expected: a version string.
- [ ] **Step 2:** In the scratchpad, `instruqt lab init` (answer prompts with a throwaway name), then `instruqt lab validate` inside it. Expected: validation passes on the untouched scaffold.
- [ ] **Step 3:** In that scratch lab, try each schema question from **Produces** by editing HCL and running `instruqt lab validate`; record yes/no + the exact working snippet in "Schema facts". Use the CLI's `--help` and the reference pages under `https://docs.labs.instruqt.com/reference/` for resource names.
- [ ] **Step 4:** Write `docs/instruqt-2-spike-checklist.md`: the spec's Phase 0 items 2–11 (item 1 is this task), each with *how to test it* (exact clicks/commands), *expected result*, and an empty *Finding* line. Item 10 includes how to time the start (stopwatch from "Start" to first page usable, three runs).
- [ ] **Step 5: Commit**

```bash
git add docs/instruqt-2-spike-checklist.md
git commit -m "docs: Instruqt 2.0 spike checklist and schema facts"
```

---

### Task 2: Pin parser

**Files:**
- Create: `tools/track-tester/ci/read_pin.py`, `tools/track-tester/ci/tests/test_read_pin.py`
- Modify: `tools/track-tester/pyproject.toml` (add `"ci"` to `pythonpath`, `"ci/tests"` to `testpaths`)

**Interfaces:**
- Produces: `read_pin(path: str, name: str) -> str` and CLI `python3 tools/track-tester/ci/read_pin.py <file.hcl> <name>` printing the value, exit 1 with `ERROR: pin '<name>' not found in <file>` or `ERROR: pin '<name>' defined more than once in <file>` on stderr. Reads the `default` of `variable "<name>" { ... }`. Stdlib only.

- [ ] **Step 1: Write the failing tests**

```python
def test_reads_default_of_variable_block(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "dapr_runtime_version" {\n  default = "1.18.7"\n}\n')
    assert read_pin(str(f), "dapr_runtime_version") == "1.18.7"

def test_tolerates_fmt_alignment_and_description(tmp_path):
    f.write_text('variable "x" {\n  description = "d"\n  default     = "a.b"\n}\n')
    assert read_pin(str(f), "x") == "a.b"

def test_does_not_match_name_prefix(tmp_path):  # "dapr_cli_version" vs "dapr_cli_version_old"
def test_ignores_commented_out_block(tmp_path):  # lines starting with # or //
def test_missing_pin_exits_1_with_error(tmp_path):  # via subprocess on the CLI; stderr contains "not found"
def test_duplicate_pin_exits_1_with_error(tmp_path):  # stderr contains "more than once"
def test_reads_real_repo_files():  # every pin listed in Global Constraints resolves from the two versions.hcl files (skip if files absent until Tasks 3/5)
```

- [ ] **Step 2:** `(cd tools/track-tester && uv run pytest ci/tests -v)` → FAIL (module missing).
- [ ] **Step 3:** Implement with one regex over comment-stripped text: `variable\s+"<name>"\s*\{(.*?)\}` (DOTALL) then `default\s*=\s*"([^"]*)"` inside the match.
- [ ] **Step 4:** Run tests → PASS. Also `uv run pytest -v` (whole harness) → PASS.
- [ ] **Step 5: Commit** `feat(track-tester): HCL pin parser for single-source version pins`

---

### Task 3: Shared `dapr-sandbox` module

**Files:**
- Create: `modules/dapr-sandbox/{main.hcl,versions.hcl,README.md}`, `modules/dapr-sandbox/scripts/{install-tools.sh,prewarm.sh,render-image-script.sh}`
- Source material: `dapr-secrets/_setup/image-dapr-secrets-install.sh` (toolchain + prewarm logic to move)

**Interfaces:**
- Consumes: `read_pin.py` (Task 2), schema facts (Task 1).
- Produces:
  - `versions.hcl` variables: `image_ref` (initially `"ubuntu:24.04"`; replaced by the built image in the runbook), `dotnet_sdk_channel` = `"10.0"`, `java_version` = `"17"`, `node_major` = `"24"`, `dapr_cli_version` = `"1.18.2"`.
  - `main.hcl` input variables: `cpu` (default `4`), `memory` (default `8192`), `lab_startup_script` (string, default `""`), `lab_environment` (map(string), default `{}`). One `resource "vm" "sandbox"` using `image_ref`, `startup_script = var.lab_startup_script`, `environment = var.lab_environment`, and an exec `health_check` that passes when `/var/lib/lab-setup/ready` exists (so the sandbox is not "ready" before lab setup finishes).
  - Output `vm` = the VM reference labs use as tab/task targets.
  - `install-tools.sh`: requires env `DOTNET_SDK_CHANNEL JAVA_VERSION NODE_MAJOR DAPR_CLI_VERSION`, exits 1 naming any that is unset; installs Docker, `dotnet-sdk-$DOTNET_SDK_CHANNEL` (backports PPA), `openjdk-$JAVA_VERSION-jdk` + `maven`, python3/venv/pip, uv into `/usr/local/bin`, Node via NodeSource `setup_$NODE_MAJOR.x`, Dapr CLI via `install.sh` with `-s $DAPR_CLI_VERSION`; ends by printing every version and failing if any command is missing.
  - `prewarm.sh`: shallow-clones the demo repo, runs `dotnet build` / `uv sync` / `mvn -q -DskipTests package` for `secrets/{dotnet,python,java}/{Demo1-ReadSecret,Demo2-Scoping/AppA,Demo2-Scoping/AppB}`, deletes the checkout; if `docker info` works, `docker pull` `daprio/dapr:<runtime>`, `redis:6`, `openzipkin/zipkin`, `hashicorp/vault:1.20` (images `dapr init` pulls: read them from `dapr init --help`/docs for 1.18 and list them as a variable at the top). Non-fatal on clone/pull failure (warn on stderr), like today.
  - `render-image-script.sh`: prints to stdout `#!/usr/bin/env bash`, `set -euo pipefail`, one `export NAME=value` per toolchain pin read with `read_pin.py` from `versions.hcl`, then the bodies of `install-tools.sh` and `prewarm.sh`. This output is what the runbook pastes into the Image Builder.

- [ ] **Step 1: Failing check** — add to `ci/tests/test_read_pin.py`: `test_render_image_script_inlines_pins` runs `render-image-script.sh` and asserts the output contains `export DAPR_CLI_VERSION=1.18.2` and `export NODE_MAJOR=24`, and that `bash -n` on the output succeeds. Run → FAIL.
- [ ] **Step 2:** Write `versions.hcl`, the three scripts, `main.hcl`, `README.md` (what it provides, inputs, output, "toolchain bump = edit versions.hcl → rebuild image per runbook → bump module version").
- [ ] **Step 3:** `uv run pytest ci/tests -v` → PASS. `shellcheck modules/dapr-sandbox/scripts/*.sh` → clean.
- [ ] **Step 4: Real install test** — `modules/dapr-sandbox/scripts/render-image-script.sh > "$SCRATCH/image.sh"` then `docker run --rm -v "$SCRATCH":/w ubuntu:24.04 bash -c 'apt-get update && apt-get install -y sudo curl wget && bash /w/image.sh'`. Expected: version block prints .NET 10.0.x, Java 17, Maven, Python 3.12, uv, Node v24, Dapr CLI 1.18.2. (Docker Engine install and image pre-pull may warn inside a container; that is acceptable here, the spike verifies them on a real VM.)
- [ ] **Step 5:** `instruqt lab fmt` in `modules/dapr-sandbox`, then `instruqt lab validate` there if Task 1 found validate accepts modules. Expected: no diff after fmt, validate passes.
- [ ] **Step 6: Commit** `feat(modules): shared dapr-sandbox module with toolchain image script`

---

### Task 4: Lab setup and shared Vault seeding

**Files:**
- Create: `dapr-secrets/scripts/seed-vault.sh`, `dapr-secrets/scripts/lab-setup.sh`
- Modify: `tools/track-tester/ci/setup-dapr-secrets.sh` (call `seed-vault.sh` instead of its inline copy; read pins with `read_pin.py`; clone demo at `tracks_src_ref`), `dapr-secrets/4-swap-the-provider/tests/challenge.robot` (`${SANDBOX_SETUP}` → run `seed-vault.sh` with the existing shims instead of slicing a script), `tools/track-tester/variables/dapr_secrets.py` (docstring path)
- Source material: `dapr-secrets/_setup/sandbox-setup.sh`

**Interfaces:**
- Consumes: `read_pin.py`; pins `dapr_runtime_version` = `"1.18.7"` and `tracks_src_ref` = the full commit SHA of the demo repo's `main` at implementation time (`git ls-remote https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git main`). Create `dapr-secrets/versions.hcl` here with just these two variables; Task 5 adds the module block.
- Produces:
  - `seed-vault.sh <secrets.json>`: `docker rm -f vault`, run `hashicorp/vault:1.20` dev mode, wait ≤30 s (`ERROR: Vault did not become ready within 30 seconds.` + exit 1), seed every key to `secret/dapr/<name>`. Same behaviour as today's inline copies.
  - `lab-setup.sh`: requires env `DAPR_RUNTIME_VERSION`, `TRACKS_SRC_REF` (exit 1 if empty). Synchronous: clone demo to `~/ai-agent-tracks-instruqt` **only if absent**, `git checkout $TRACKS_SRC_REF` only on fresh clone; `dapr init --runtime-version $DAPR_RUNTIME_VERSION` only if the three Dapr containers are not running; copy `secrets.example.json` → `secrets.json`; `seed-vault.sh`; `mkdir -p /var/lib/lab-setup && touch /var/lib/lab-setup/ready`. Then **background** (`nohup … &`, log to `/var/log/lab-prebuild.log`): pre-build Demo1 and Demo2 AppA/AppB in all three languages (replaces the four per-challenge `setup.sh`). No `docker login`.
  - The Robot suite for ch4 keeps its two cases (never-ready fails with the message; ready passes).

- [ ] **Step 1:** Change the ch4 Robot case "The Vault Wait Loop Fails When Vault Never Becomes Ready" to run `bash dapr-secrets/scripts/seed-vault.sh <tmp secrets.json>` with the existing `docker`/`sleep` shims on `PATH`. Run `(cd tools/track-tester && uv run robot --include vault ../../dapr-secrets/4-swap-the-provider/tests/challenge.robot)` → FAIL (script missing).
- [ ] **Step 2:** Write `seed-vault.sh` and `lab-setup.sh`; switch `setup-dapr-secrets.sh` to `read_pin.py` (`DAPR_RUNTIME_VERSION` from `dapr-secrets/versions.hcl`, `DAPR_CLI_VERSION` from `modules/dapr-sandbox/versions.hcl`), to `seed-vault.sh`, and to `git -C "$TRACKS_SRC_DIR" checkout "$TRACKS_SRC_REF"` after clone. Replace its `bash -n sandbox-setup.sh` with `bash -n` on both new scripts.
- [ ] **Step 3:** Robot `--include vault` run → PASS.
- [ ] **Step 4: Re-run safety (Review Focus 3)** — with Docker running locally: `TRACKS_SRC_DIR` unset, `HOME=$SCRATCH/home DAPR_RUNTIME_VERSION=1.18.7 TRACKS_SRC_REF=<pin> bash dapr-secrets/scripts/lab-setup.sh` twice; between runs append a line to a file in the clone. Expected: both runs exit 0, the appended line survives, `docker ps` shows one `vault` and the Dapr containers not recreated (same container IDs). Then `DAPR_RUNTIME_VERSION= bash dapr-secrets/scripts/lab-setup.sh` → exit 1 naming the variable (Review Focus 2).
- [ ] **Step 5:** `bash tools/track-tester/ci/setup-dapr-secrets.sh` locally → completes, prints the pinned versions. `shellcheck dapr-secrets/scripts/*.sh` → clean.
- [ ] **Step 6: Commit** `feat(dapr-secrets): lab setup script and shared Vault seeding`

---

### Task 5: Lab HCL — lab, sandbox, layout, tabs, pages

**Files:**
- Create: `dapr-secrets/{main.hcl,layouts.hcl,tabs.hcl,pages.hcl}`
- Modify: `dapr-secrets/versions.hcl` (add the module block), `dapr-secrets/4-swap-the-provider/assignment.md` (closing section)

**Interfaces:**
- Consumes: module input/output names from Task 3; schema facts from Task 1; `scripts/lab-setup.sh` (Task 4).
- Produces: page resource names `page.what_is_the_secrets_api`, `page.component_and_parameters`, `page.secret_scoping`, `page.swap_the_provider`; terminal resources `terminal.dapr_cli`, `terminal.curl`; editor resource (type per Task 1) `editor`. Task 6 adds `activities` to the last two pages.

- [ ] **Step 1:** `versions.hcl`: add `module "sandbox"` with `source = "diagrid/dapr-sandbox"`, `version = "1.0.0"` (exact), `variables = { lab_startup_script = file("scripts/lab-setup.sh"), lab_environment = { DAPR_RUNTIME_VERSION = var.dapr_runtime_version, TRACKS_SRC_REF = var.tracks_src_ref } }`. If Task 1 found registry modules can't be referenced before publishing, use the local `source = "../modules/dapr-sandbox"` until the runbook's publish step, and say so in a comment. If `file()` is unsupported, use the alternative recorded in Task 1's schema facts.
- [ ] **Step 2:** `main.hcl`: title "Dapr Secrets - Read, Scope, and Swap Secret Stores", description from `dapr-secrets/README.md` "Description" section, `layout = resource.layout.main`, time limit `30m`, idle timeout 10 min and extra time 10 min if the schema has them (else note in README), one chapter `secrets` with the four pages in order.
- [ ] **Step 3:** `tabs.hcl` + `layouts.hcl`: instructions column + tabs **Editor**, **Dapr CLI**, **curl**, all targeting `module.sandbox.output.vm`, working directory `/root/ai-agent-tracks-instruqt/secrets` (path from the challenge `tabs.md`).
- [ ] **Step 4:** `pages.hcl`: titles from each challenge `README.md` `# Name`; `file = "<N-slug>/assignment.md"`.
- [ ] **Step 5:** In `4-swap-the-provider/assignment.md`, replace "Please take a moment to rate this training and provide feedback in the next step" with an `<instruqt-completion text="You've completed Dapr Secrets!"></instruqt-completion>` at the end and adjust the sentence to refer to it.
- [ ] **Step 6:** `(cd dapr-secrets && instruqt lab fmt && instruqt lab validate)` → no diff, validate passes. Run doc-sync on all four challenges (command in AGENTS.md) → passes.
- [ ] **Step 7: Commit** `feat(dapr-secrets): Instruqt 2.0 lab definition`

---

### Task 6: Tasks for challenges 3 and 4

**Files:**
- Create: `dapr-secrets/tasks.hcl`; `dapr-secrets/3-secret-scoping/scripts/check-{config-present,app-a-reads,app-b-answers,app-b-refused,app-b-allowed}.sh`; `dapr-secrets/4-swap-the-provider/scripts/check-{app-answers,vault-loaded,app-reads}.sh`
- Modify: `dapr-secrets/pages.hcl` (activities), both `solve.sh` (drop `fail-message`/legacy-only bits), both `assignment.md` (add `<instruqt-task id="...">` where the learner is asked to check)

**Interfaces:**
- Consumes: page names from Task 5, `module.sandbox.output.vm`.
- Produces: `resource "task" "scoping"` and `resource "task" "swap_provider"`, page activity keys `scoping` and `swap_provider`.

Condition → script → `failure_message` mapping (copy each message from the matching `fail-message` branch of today's `check.sh`, replacing interpolated values with plain wording):

| Task | Condition | Passes when |
| --- | --- | --- |
| scoping | `config_present` | `config-app-b.yaml` exists in any language's `Demo2-Scoping/resources` |
| scoping | `app_a_reads` | `:5002/secret/orderdb-password` → 200 |
| scoping | `app_b_answers` | `:5003` answers (status ≠ 000) |
| scoping | `app_b_refused` | `:5003/secret/orderdb-password` → 403 (message covers both "still 200" and "other status") |
| scoping | `app_b_allowed` | `:5003/secret/payments-api-key` → 200 |
| swap_provider | `app_answers` | `:5001` answers |
| swap_provider | `vault_loaded` | metadata shows `secretstore` of type `secretstores.hashicorp.vault` |
| swap_provider | `app_reads` | `:5001/secret/orderdb-password` → 200 |

Each condition's `solve` is the challenge's `solve.sh` on the first condition only.

- [ ] **Step 1:** Write the check scripts (each self-contained, `TRACKS_SRC_DIR` default as today, exit 0/1, a one-line echo on success), `tasks.hcl`, page activities, and the `<instruqt-task>` tags.
- [ ] **Step 2: Verify the checks against a running app** — run challenge 3's Robot suite for one language to bring the apps up in the scoped state, or start them by hand per the assignment; then run each `check-*.sh` → exit 0. Stop app B → `check-app-b-answers.sh` exits 1. Do the same for challenge 4 with Demo1 (not swap) running → `check-vault-loaded.sh` exits 1.
- [ ] **Step 3:** `shellcheck` on all new scripts → clean; `instruqt lab fmt && instruqt lab validate` → pass; doc-sync for ch3 and ch4 → pass.
- [ ] **Step 4: Commit** `feat(dapr-secrets): 2.0 tasks for scoping and provider swap`

---

### Task 7: CI — lab validation, pinned demo ref, required-check-safe triggers

**Files:**
- Create: `.github/workflows/lab-validate.yml`
- Modify: `.github/workflows/test-dapr-secrets.yml`

**Interfaces:**
- Consumes: CLI version from Task 1; `read_pin.py`.
- Produces: required-check job names for the ruleset: `lab-validate`, `docsync`, `languages (dotnet)`, `languages (java)`, `languages (python)`, `languages (shared)`.

- [ ] **Step 1:** `lab-validate.yml`: triggers on **every** `pull_request` (no `paths`) and `workflow_dispatch`; one job `lab-validate`: install the pinned CLI from `https://github.com/instruqt/cli/releases/download/<ver>/instruqt-linux.zip`; for each dir in `modules/dapr-sandbox dapr-secrets`: `instruqt lab fmt` then `git diff --exit-code`, `instruqt lab validate`; `shellcheck` on `modules/**/scripts/*.sh` and `dapr-secrets/**/scripts/*.sh`; `uv run pytest -v` in `tools/track-tester`.
- [ ] **Step 2:** `test-dapr-secrets.yml` (Review Focus 4): remove `pull_request.paths`; add a `changes` job using `dorny/paths-filter@v3` with filter `dapr-secrets/**`, `modules/dapr-sandbox/**`, `tools/track-tester/**`, `.github/workflows/test-dapr-secrets.yml`; gate `docsync` and `languages` with `if: github.event_name != 'pull_request' || needs.changes.outputs.relevant == 'true'` (a job skipped by `if` satisfies a required check). Gate `report` the same way as today.
- [ ] **Step 3:** Pin the demo checkout: add a step before the demo `actions/checkout` that runs `read_pin.py dapr-secrets/versions.hcl tracks_src_ref` into `$GITHUB_OUTPUT`, and pass it as `ref:`. Replace the "Deliberately NOT pinned" comment with the new rule: the lab and CI test the same pinned ref; demo changes arrive by bumping `tracks_src_ref` in a PR.
- [ ] **Step 4:** Lint both workflows with `actionlint` if available (`brew install actionlint`) → clean. Push the branch and open a draft PR; expected: `lab-validate` and the dapr-secrets jobs run and pass. Then push a commit touching only `dapr-101/README.md` on a throwaway branch/PR: expected dapr-secrets `docsync`/`languages` show **Skipped**, not pending. Close the throwaway PR.
- [ ] **Step 5: Commit** `ci: validate Instruqt labs, pin demo ref, make dapr-secrets checks requirable`

---

### Task 8: Admin runbook

**Files:**
- Create: `docs/instruqt-2-runbook.md`

**Interfaces:**
- Consumes: everything above (names, paths, job names, CLI version).

- [ ] **Step 1:** Write the runbook with the nine sections from the spec's "Admin runbook" list, each as numbered click-by-click steps with exact field values (`diagrid`, `dapr-secrets`, `main`, `modules/dapr-sandbox`, `diagrid/dapr-sandbox`, version `1.0.0`) and an **Expected** line. Order them as the owner must do them: (1) GitHub App, (2) render + build image (`modules/dapr-sandbox/scripts/render-image-script.sh | pbcopy`), PR to set `image_ref`, (3) publish module 1.0.0, (4) secrets (state that none are expected), (5) import lab, (6) preview + acceptance play-through with a checklist per page × language and the 1:30 timing, (7) required checks — list the job names from Task 7 and note that `lab-validate` must have run once before it appears, (8) `INSTRUQT_TOKEN` (optional), (9) embed. Add a "Toolchain bump" and a "Demo repo bump" procedure.
- [ ] **Step 2:** Self-check: every path, job name and value in the runbook exists in the repo (`git grep` each one).
- [ ] **Step 3: Commit** `docs: Instruqt 2.0 admin runbook`

---

### Task 9: Repo docs and authoring skill

**Files:**
- Modify: `AGENTS.md`, `.claude/skills/creating-dapr-university-tracks/SKILL.md`, `.claude/skills/creating-dapr-university-tracks/reference.md`, `tools/track-tester/README.md`, `dapr-secrets/README.md` (rewrite as a human readme: what the lab is, file map, how to preview, link to runbook; the config now lives in `main.hcl`)

- [ ] **Step 1:** Update the docs: 2.0 lab layout, `modules/`, the two `versions.hcl` files and `read_pin.py`, deploy = merge to `main`, `lab-validate` job, `dapr-secrets` as the first 2.0 lab; the skill says new tracks are 2.0 labs using `diagrid/dapr-sandbox`. Legacy-track guidance stays for the other tracks.
- [ ] **Step 2:** `git grep -n "sandbox-setup.sh\|_setup/" -- dapr-secrets AGENTS.md .claude tools/track-tester` → only intentional references to other tracks remain.
- [ ] **Step 3: Commit** `docs: describe Instruqt 2.0 labs and the shared sandbox module`

---

### Checkpoint: owner runs the spike and runbook

Stop and hand over. The owner works through `docs/instruqt-2-spike-checklist.md` and runbook sections 1–6, recording findings in the checklist. Resume with Task 10 when findings are in.

### Task 10: Apply spike findings

**Files:** whatever the findings touch; always `docs/instruqt-2-spike-checklist.md` and the spec's Phase 0 section (record outcomes).

- [ ] **Step 1:** For each finding that differs from what Tasks 3–7 assumed, make the change and re-run that task's verification step. Known branches:
  - Alerts or `<details>` don't render → convert in all four assignments to the 2.0 equivalent; if the `<summary>` language markers change, update `LANG_BY_SUMMARY`/`_lang_from_summary` in `tools/track-tester/docsync/check_doc_sync.py` with a new test in `docsync/tests/test_extract.py` for the new marker, then run `uv run pytest -v` and doc-sync on all challenges.
  - Start > 1:30 → move the slowest synchronous step of `lab-setup.sh` into the image (`prewarm.sh`) or into the background part; re-time.
  - Docker daemon not available during image build → drop the pre-pull, and confirm anonymous pulls at launch work without rate-limit errors; if they don't, raise it with the owner (no PAT in the VM env).
- [ ] **Step 2:** Owner re-plays the lab (runbook section 6) → all pages pass in .NET, Python, Java; start ≤ 1:30.
- [ ] **Step 3: Commit** `fix(dapr-secrets): apply Instruqt 2.0 spike findings`

### Task 11: Remove legacy files (only after acceptance passes)

**Files:**
- Delete: `dapr-secrets/_setup/`, `dapr-secrets/*/tabs.md`, `dapr-secrets/[1-4]-*/README.md`, `dapr-secrets/*/scripts/setup.sh`, `dapr-secrets/[34]-*/scripts/check.sh`

- [ ] **Step 1:** Delete the files. `git grep` for each deleted path → no references left.
- [ ] **Step 2:** `instruqt lab validate` in `dapr-secrets`, `uv run pytest -v`, doc-sync all challenges, and `uv run robot --dryrun ../../dapr-secrets/*/tests/challenge.robot` → all pass.
- [ ] **Step 3: Commit** `chore(dapr-secrets): remove legacy track files`, push, and mark the PR ready for review.
