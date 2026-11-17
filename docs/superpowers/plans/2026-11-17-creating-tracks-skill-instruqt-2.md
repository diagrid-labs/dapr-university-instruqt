# creating-dapr-university-tracks skill on Instruqt 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite the repo skill `.claude/skills/creating-dapr-university-tracks/` so its main path
teaches only the Instruqt 2.0 lab style of `dapr-secrets` and `dapr-pubsub`, with the 1.0 guidance
moved to a separate file.

**Architecture:** Three Markdown files. `legacy-1.0.md` receives the existing 1.0 text first, so
nothing is lost. Then `SKILL.md` (short, read in full every time) and `reference.md` (templates and
detail) are rewritten for 2.0 only. A final task runs the spec's acceptance checks, including a
reading test by a fresh agent.

**Tech Stack:** Markdown (Claude Code skill format with YAML frontmatter), grep for checks.

**Spec:** `docs/superpowers/specs/2026-11-17-creating-tracks-skill-instruqt-2-design.md`. Read it
in full before starting. "Content the skill must teach" is the checklist for Tasks 2 and 3.

## Global Constraints

- Every rule in `SKILL.md` and `reference.md` must be checkable against `dapr-secrets/` or
  `dapr-pubsub/` on `main`. Before writing a rule, open the lab file it describes.
- `SKILL.md` stays at or under 249 lines.
- No volatile values in the skill: no version numbers, commit SHAs, module version, cron times,
  report years or blog links. Point to the file that holds the value (`versions.hcl`,
  `modules/dapr-sandbox/versions.hcl`, the workflows, the newest lab's final page).
- Long HCL and shell files are described as "copy `<file>` from `dapr-pubsub` and change X, Y, Z",
  not pasted in full. Short fragments (a callout, a `variable` block, a page entry) may be shown.
- Do not repeat content owned by `AGENTS.md`, `docs/instruqt-2-runbook.md`,
  `docs/instruqt-2-spike-checklist.md` or `modules/dapr-sandbox/README.md`. Link to them.
- Learner-facing terms: **track** (the whole course) and **lab** (one page). Config terms: `lab`,
  `chapter`, `page`.
- Frontmatter `name: creating-dapr-university-tracks` (was `creating-university-tracks`).
- This change edits only the three skill files. It does not change labs, the module, the harness,
  CI, `AGENTS.md` or the runbook.
- Assume the `dapr-secrets-remove-legacy-files` branch (removes `dapr-secrets/_setup/` and the
  per-page `README.md`, `notes.md`, `tabs.md`, `scripts/setup.sh`) is merged first or together.
  So the skill does **not** say "dapr-secrets still contains leftover 1.0 files"; it only says a
  2.0 lab never has those files. (This replaces the spec's "the skill says so" for leftovers,
  because the leftovers are gone.) `dapr-secrets/README.md` stays: it is a human file map, not
  1.0 config.

## Review Focus

The requests the skill will meet that the spec implies but no rule spells out, most likely first.
Each is a prompt in the Task 4 reading test.

1. **Adding a page to an existing 2.0 lab** (not scaffolding a new one): the agent should add the
   folder, a `pages.hcl` entry, a `main.hcl` page entry, the suite, update the minutes line, and
   not touch the module.
2. **Editing a legacy 1.0 track** (for example a `dapr-101` assignment): the agent should find
   `legacy-1.0.md` and follow it, not apply 2.0 rules such as the H1.
3. **A lab that needs a tool or container image not in the sandbox image**: the agent should name
   the module change (image rebuild, new module version, publish before pin) as an owner step and
   not install it in `lab-setup.sh` at boot.
4. **A single-language lab**: the agent should drop the `<details>` blocks and shrink the CI matrix,
   not invent empty Python/Java folders.
5. **A service tab that only works from a later page** (like RabbitMQ): the agent should add a
   second layout and set `layout` on that page entry.

---

### Task 1: Move the 1.0 guidance to `legacy-1.0.md`

**Files:**
- Create: `.claude/skills/creating-dapr-university-tracks/legacy-1.0.md`
- Read (source, do not change yet): `.claude/skills/creating-dapr-university-tracks/SKILL.md`,
  `.claude/skills/creating-dapr-university-tracks/reference.md`

**Interfaces:**
- Produces: the file `legacy-1.0.md`, which Task 2 links from `SKILL.md` by that exact name.

- [ ] **Step 1: Write the check and run it to see it fail**

Run:
```bash
f=.claude/skills/creating-dapr-university-tracks/legacy-1.0.md
test -f $f && head -3 $f | grep -q "Only for editing the legacy tracks" \
  && for s in "Track README.md template" "Challenge README.md template" "notes.md" "tabs.md" \
     "sandbox-setup.sh" "check.sh" "solve.sh" "Instruqt-Var" "image-<slug>-install.sh"; do
       grep -q -- "$s" $f || echo "MISSING: $s"; done
```
Expected: fails, because the file does not exist.

- [ ] **Step 2: Create `legacy-1.0.md`**

First line under the H1 is exactly: "Only for editing the legacy tracks: dapr-101, dapr-workflow,
dapr-workflow-aspire, dapr-dotnet-aspire, dapr-agents, dapr-agents-web-context,
ai-agents-deepagents, ai-agents-maf, catalyst-101. New tracks are 2.0 labs: see SKILL.md."

Move into it, with light edits only: from `SKILL.md` the 1.0 directory structure, the track and
challenge `README.md` templates, the Instruqt-Var line, the "Instruqt Check / Solve buttons"
section, the 1.0 rows of Common mistakes and Checklist; from `reference.md` the `notes.md`
templates, `tabs.md`, the `_setup/sandbox-setup.sh`, per-challenge scripts and image install
sections, the 1.0 parts of source-code models, `Instruqt-Var`-related pre-flight checks, the
1.0-era closing-section wording, and the reference-tracks table rows for 1.0 tracks. Remove
statements that describe `dapr-secrets` as a 1.0 model (it is a 2.0 lab).

- [ ] **Step 3: Run the check from Step 1**

Expected: no output and exit 0.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/creating-dapr-university-tracks/legacy-1.0.md
git commit -m "docs(skill): move the Instruqt 1.0 track guidance to legacy-1.0.md"
```

---

### Task 2: Rewrite `SKILL.md` for 2.0 labs

**Files:**
- Modify (rewrite): `.claude/skills/creating-dapr-university-tracks/SKILL.md`

**Interfaces:**
- Consumes: `legacy-1.0.md` from Task 1 (linked once, in the overview).
- Produces: section names Task 3 links to from `reference.md`: `## Sizing`, `## Lab layout`,
  `## Workflow`, `## Assignment quick reference`, `## Common mistakes`, `## Checklist`.

- [ ] **Step 1: Write the checks and run them to see them fail**

Run:
```bash
f=.claude/skills/creating-dapr-university-tracks/SKILL.md
[ "$(wc -l < $f)" -le 249 ] || echo "TOO LONG"
grep -q '^name: creating-dapr-university-tracks$' $f || echo "NAME"
[ "$(grep -c 'legacy-1.0.md' $f)" -eq 1 ] || echo "LEGACY LINK COUNT"
grep -n -E 'notes\.md|tabs\.md|_setup|sandbox-setup\.sh|tasks\.hcl|check\.sh|solve\.sh|Instruqt-Var|Time limit \(minutes\)' $f \
  | grep -v -i -E 'never|not |no |don.t|legacy-1\.0' && echo "1.0 INSTRUCTION FOUND"
for s in "## Sizing" "## Lab layout" "## Workflow" "## Assignment quick reference" "## Common mistakes" "## Checklist"; do
  grep -q "^$s" $f || echo "MISSING SECTION: $s"; done
```
Expected: at least NAME, MISSING SECTION and 1.0 INSTRUCTION FOUND lines.

- [ ] **Step 2: Rewrite `SKILL.md`**

Cover, from the spec's "Content the skill must teach": the frontmatter (name above; description
with only 2.0 terms plus "and for editing the legacy 1.0 tracks"); overview with the one
`legacy-1.0.md` link; Terminology; Sizing (including "rounded down"); Lab layout (root files and
page folders as a tree, plus the "never present" list); Workflow (scope with the user, study
`dapr-pubsub`, demo code in `ai-agent-tracks-instruqt`, root files, pages, `lab-setup.sh`, tests
and CI, local validation, owner hand-off); Assignment quick reference (annotation table, callout
types, the Run-section pattern in short form, `## Before you start` vs. "is it running" rule);
Languages (default and the reduced variant); Common mistakes (every row listed in the spec);
Checklist (2.0 only). Detail goes to `reference.md` with a pointer per section.

- [ ] **Step 3: Run the checks from Step 1**

Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add .claude/skills/creating-dapr-university-tracks/SKILL.md
git commit -m "docs(skill): rewrite SKILL.md for Instruqt 2.0 labs"
```

---

### Task 3: Rewrite `reference.md` for 2.0 labs

**Files:**
- Modify (rewrite): `.claude/skills/creating-dapr-university-tracks/reference.md`

**Interfaces:**
- Consumes: section names from Task 2.
- Produces: the sections `## Root files`, `## lab-setup.sh`, `## Page anatomy`,
  `## Multi-language pattern`, `## Images and badges`, `## website-description.md`,
  `## Demo apps and sandbox content`, `## Drift tests and CI`, `## Local validation`,
  `## Owner hand-off`.

- [ ] **Step 1: Write the checks and run them to see them fail**

Run:
```bash
f=.claude/skills/creating-dapr-university-tracks/reference.md
for s in "## Root files" "## lab-setup.sh" "## Page anatomy" "## Multi-language pattern" \
  "## Images and badges" "## website-description.md" "## Demo apps and sandbox content" \
  "## Drift tests and CI" "## Local validation" "## Owner hand-off"; do
  grep -q "^$s" $f || echo "MISSING SECTION: $s"; done
grep -n -E 'notes\.md|tabs\.md|_setup|sandbox-setup\.sh|tasks\.hcl|check\.sh|solve\.sh|Instruqt-Var' $f \
  | grep -v -i -E 'never|not |no |don.t|legacy-1\.0|module.s|/usr/local/lib/dapr-sandbox' && echo "1.0 INSTRUCTION FOUND"
grep -n -E '[0-9]+\.[0-9]+\.[0-9]+|[0-9a-f]{40}|cron:|State of Dapr 20[0-9]{2}' $f && echo "VOLATILE VALUE"
for s in "instruqt-completion" "Finish & Exit" "require-anchored-cd" "Before you start" \
  "What's next?" "Try these Dapr tools" "validate-lab.sh" "lab-validate.yml" "read_pin.py" \
  "Toolchain bump" "Checkpoint B" "flatten" "rounded down"; do
  grep -q -- "$s" $f || echo "MISSING: $s"; done
```
Expected: MISSING SECTION and MISSING lines.

- [ ] **Step 2: Rewrite `reference.md`**

One section per item in the spec's "Content the skill must teach" that `SKILL.md` only summarizes:
each root file (what it holds, what to copy from which lab, what to change), `lab-setup.sh`
contract, the full page anatomy (first, middle, final page, items 1 to 11 of the spec's assignment
conventions, with the exact callout texts), the multi-language pattern with folder spellings,
images (raw `main` URL, alt text, flatten transparent diagrams onto white) and badges, the prose
`website-description.md`, demo apps and sandbox content (including the module-change path and the
API-key note marked untested in 2.0), drift tests and CI (every file a new lab adds, modelled on
`dapr-pubsub`), local validation commands, and the owner hand-off pointing to the runbook's
"Checkpoint B" and "Toolchain bump" sections. Keep the existing robot suite conventions list and
the doc-sync coverage block explanation, updated to 2.0.

- [ ] **Step 3: Run the checks from Step 1**

Expected: no output.

- [ ] **Step 4: Check every rule against the labs**

For each callout text, file name and path in `reference.md`, `grep -rF` it in `dapr-pubsub/`,
`dapr-secrets/`, `tools/track-tester/` or `.github/workflows/`. Expected: each one is found, or
the sentence is about something the skill tells the author to create (for example
`test-<lab>.yml`).

- [ ] **Step 5: Commit**

```bash
git add .claude/skills/creating-dapr-university-tracks/reference.md
git commit -m "docs(skill): rewrite reference.md for Instruqt 2.0 labs"
```

---

### Task 4: Acceptance and PR

**Files:**
- None changed, unless the reading test finds a gap (then fix it in `SKILL.md` or `reference.md`).

**Interfaces:**
- Consumes: all three skill files.

- [ ] **Step 1: Re-run the checks of Tasks 1 to 3**

Expected: no output from any of them.

- [ ] **Step 2: Reading test with a fresh agent**

Dispatch one general-purpose subagent per prompt below. Each gets only: "Read
`.claude/skills/creating-dapr-university-tracks/SKILL.md` (and the files it points to as needed).
Do not create or edit files. Answer with the list of files you would create or change and the
steps, including anything that needs the repo owner." Prompts and what a pass looks like:

1. "Scaffold a 3-page dapr-state lab." Pass: root HCL files, `scripts/lab-setup.sh`,
   `website-description.md`, three page folders with `assignment.md` and `tests/challenge.robot`,
   `variables/dapr_state.py`, `ci/setup-dapr-state.sh`, `test-dapr-state.yml`, `lab-validate.yml`
   loops, `AGENTS.md`/`README.md` tables, owner steps named as pending; no 1.0 files.
2. "Add a 7th page to dapr-pubsub." Pass: Review Focus item 1.
3. "Fix a typo in a dapr-101 assignment and add a step." Pass: uses `legacy-1.0.md`, no H1 added.
4. "The new lab needs Kafka." Pass: Review Focus item 3.
5. "Make the dapr-state lab .NET only." Pass: Review Focus item 4.
6. "Page 3 of the dapr-state lab needs a Zipkin tab." Pass: Review Focus item 5.

Expected: all six pass. For a fail, fix the skill text that misled the agent, commit, and re-run
that prompt.

- [ ] **Step 3: Push and open the PR**

PR description lists the spec's "Out of scope, follow-up" items that are still open:
`AGENTS.md` harness map lists `test_secrets_checks`, `test_pubsub_checks`,
`test_pubsub_lib_checks`; "on a later lab" in `dapr-pubsub/1-subscription-types/assignment.md`.
It notes the dependency on the `dapr-secrets-remove-legacy-files` branch.

```bash
git push -u origin HEAD
gh pr create --base main --title "docs(skill): update creating-dapr-university-tracks to Instruqt 2.0 labs"
```
