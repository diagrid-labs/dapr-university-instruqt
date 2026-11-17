# Design: update the `creating-dapr-university-tracks` skill to the Instruqt 2.0 lab style

Date: 2026-11-17
Status: draft, for review

## Intent

The repo skill at `.claude/skills/creating-dapr-university-tracks/` (`SKILL.md` and `reference.md`)
is meant to be used when someone creates a new Dapr University track. New tracks are now
Instruqt 2.0 labs, but the skill is still written around legacy 1.0 tracks: track and challenge
`README.md` config, `notes.md`, `tabs.md`, `_setup/sandbox-setup.sh`, `check.sh`/`solve.sh` and
Instruqt variables. 2.0 notes were added on top in a few paragraphs, so the skill now contradicts
itself. For example, it says "no H1 in `assignment.md`" while every 2.0 page starts with one, it
tells authors to add `check.sh`/`solve.sh` even though 2.0 labs have no page checks, and it
describes `dapr-secrets` as having `notes.md`, `tabs.md` and `scripts/setup.sh`, which are legacy
leftovers that no longer drive the lab.

The goal is a skill an agent can follow from start to finish to produce a new 2.0 lab that looks,
reads and is tested like `dapr-secrets` and `dapr-pubsub`, without first having to sort out which
paragraphs still apply.

## Goals

- The main path in `SKILL.md` describes only the 2.0 lab: its files, conventions, workflow and
  checklist.
- Every rule in the skill can be checked against `dapr-secrets` or `dapr-pubsub` as they are on
  `main` today (including the PR #188 conventions, see "Assignment conventions" below).
- The skill covers the whole lifecycle of a new lab: scoping, files, page writing, sandbox setup,
  drift tests and CI, local validation, and the hand-off to the owner's Instruqt steps.
- Legacy 1.0 guidance stays available for editing the existing 1.0 tracks, but it is moved out of
  the main path.

## Non-goals

- Migrating any 1.0 track to 2.0.
- Changing the labs, the module, the harness or CI. The skill describes them; it does not change
  them. Mismatches found while writing the skill are listed for follow-up, not fixed in this change
  (see "Out of scope, follow-up").
- Repeating content that already has an owner: `AGENTS.md` ("Instruqt 2.0 labs" section, harness
  details), `docs/instruqt-2-runbook.md` (owner/Instruqt UI steps), `docs/instruqt-2-spike-checklist.md`
  (schema facts) and `modules/dapr-sandbox/README.md`. The skill links to them.

## Anti-goals

These would make the update a failure even if every file were technically correct:

- An agent following the skill creates a 1.0 artifact for a new lab: `README.md` config,
  `notes.md`, `tabs.md`, `_setup/`, `tasks.hcl`, `check.sh`/`solve.sh` or `Instruqt-Var`.
- The skill copies volatile values (version numbers, commit SHAs, module version, cron times, report
  years, blog links) that go stale. It must point to where those values live instead.
- The skill gets longer and harder to follow than it is now. The 2.0 lab is simpler than a 1.0
  track (no notes, no checks, no per-challenge config), and the skill should reflect that.
  **Budget (my call):** `SKILL.md` stays at or under its current 249 lines. `reference.md` may grow
  to hold the detail, but long HCL and shell files are described as "copy this file from
  `dapr-pubsub` and change X, Y, Z" rather than pasted in full. `legacy-1.0.md` has no budget,
  since only legacy editing reads it.

## Structure of the updated skill

Three files in `.claude/skills/creating-dapr-university-tracks/`:

| File | Content |
| --- | --- |
| `SKILL.md` | Frontmatter, overview, sizing, file layout of a 2.0 lab, workflow, the assignment quick reference (annotations and callouts), common mistakes, checklist. 2.0 only. Short enough to read in full every time. |
| `reference.md` | Full templates and detail for a 2.0 lab: every root HCL file, `lab-setup.sh`, the anatomy of first / middle / final pages, multi-language pattern, images, `website-description.md`, drift tests and CI, local validation, owner hand-off. 2.0 only. |
| `legacy-1.0.md` | New. All current 1.0 guidance moved here more or less as it is (README config templates, `notes.md`, `tabs.md`, `_setup/` scripts, per-challenge `setup.sh`/`check.sh`/`solve.sh`, `Instruqt-Var`, image install scripts), behind one line at the top: "Only for editing the legacy tracks: dapr-101, dapr-workflow, dapr-workflow-aspire, dapr-dotnet-aspire, dapr-agents, dapr-agents-web-context, ai-agents-deepagents, ai-agents-maf, catalyst-101." |

`SKILL.md` mentions `legacy-1.0.md` once, in the overview, and nowhere else.

**Frontmatter (my call):** the `name` changes from `creating-university-tracks` to
`creating-dapr-university-tracks` so it matches the folder name. The `description` is rewritten to
mention only 2.0 terms (HCL config, `diagrid/dapr-sandbox` module, pages, layouts, `lab-setup.sh`,
drift tests) plus "and for editing the legacy 1.0 tracks". Drop `README.md config`, `notes.md`,
`tabs.md` and `check/solve validation` from it.

## Content the skill must teach

The lists below are the facts, taken from the two reference labs. The builder decides the wording
and how they are split between `SKILL.md` and `reference.md`, but each item must appear.

### Terminology

- In learner-facing text, the whole course is the **track** and each page is a **lab**: "This
  hands-on lab takes about N minutes to complete", "In the next lab you'll…", "complete the 4 labs".
  In config and the skill's own prose, Instruqt's terms are **lab** (the whole thing, `resource
  "lab"`), **chapter** and **page**. The skill must explain this mismatch once, because it confuses
  people.
- "Challenge" is a 1.0 term. The page folders are still named `<n>-<slug>/` and suites still say
  `Ch3`, which is fine.

### Sizing

- Default: 3 to 5 pages, about 5 to 8 minutes each, `timelimit.duration = "30m"`,
  `extend = "10m"`, `idle.timeout = "10m"` (the `dapr-secrets` values).
- Ask the user before going over 5 pages or 30 minutes. `dapr-pubsub` (6 pages / 45 minutes) is an
  approved exception, not a precedent.
- The "You'll probably need around N minutes to complete the M labs." line in `main.hcl` is the
  sum of the per-page estimates **rounded down** (`dapr-secrets`: 25, `dapr-pubsub`: 40), and it
  stays under the time limit.

### Lab root files

For each file: what it holds and which reference lab to copy it from.

- `main.hcl`: the `lab` resource. Description shape (copy it exactly, change the bullets and
  numbers): "In this self-paced track, you'll learn:" plus bullets; the "around N minutes" line; the
  sandbox line "The sandbox is available for N minutes in total, and you can extend that time by 10
  minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to
  restart the track."; and, only when a badge exists, "Complete the track to collect the Dapr
  University <topic> badge." plus the badge image. Then `settings` (timelimit with `show_timer`,
  idle with `show_warning`), `layout = resource.layout.main`, one `chapter` with one `page` entry
  per page. A page that needs a different layout sets `layout` on its page entry (`dapr-pubsub`
  page 6).
- `pages.hcl`: one `resource "page"` per page, `title` and `file = "<n>-<slug>/assignment.md"`.
  The page `title` is the same text as the H1 of its `assignment.md`.
- `layouts.hcl`: instructions on the left (40), right side (60) with a top row holding the
  **Dev Dashboard** tab and then the **Editor** tab (the Editor is declared last with
  `active = true`, because declaring it first did not make it open by default) and a bottom row with
  the **Dapr CLI** and **curl** terminals side by side, both visible (Run buttons only reach a
  terminal that is visible on the page). Explain the comments that carry these reasons and keep
  them. An extra service tab that only works from some page on (RabbitMQ) goes in a second layout
  that differs only in that tab, as `dapr-pubsub` does.
- `tabs.hcl`: `service "editor"` (code-server on 8888), `service "dev_dashboard"` (9090 with the
  `Host`/`Origin` custom request headers, and the comment explaining why), `terminal "dapr_cli"` and
  `terminal "curl"` with `working_directory = "/root/ai-agent-tracks-instruqt/<folder>"`. Extra
  services as needed.
- `versions.hcl`: the lab pins `dapr_runtime_version` and `tracks_src_ref` as plain
  `variable "<name>" { default = "<value>" }` blocks, and the `module "sandbox"` block with
  `source = "diagrid/dapr-sandbox"`, an exact `version`, and the inputs `dapr_runtime_version`,
  `demo_repo_ref`, `editor_folder`, `lab_startup_script` (and `demo_repo_url` only if the demo is
  not in `ai-agent-tracks-instruqt`). The skill states the rules and points to `AGENTS.md` for the
  rest: each pin lives in exactly one file, `dapr_runtime_version` equals
  `prewarm_dapr_runtime_version` in `modules/dapr-sandbox/versions.hcl`, and a module version must
  be published in Instruqt before a lab pins it. Values are copied from the newest lab when writing,
  not from the skill.
- `scripts/lab-setup.sh`: only the lab's own steps. It runs after the module's shared setup (Docker,
  DNS, demo clone at the pinned ref, Editor, Dev Dashboard, `dapr init` are already done), inside a
  subshell under `set -euo pipefail`. It can use `log`, `die`, `bounded`, `wait_for_docker`,
  `TRACKS_SRC_DIR`, `LAB_SETUP_LOG`. It must be safe to run again, must not touch the ready marker,
  and starts the demo pre-build as a fully detached background job (own stdin/stdout/stderr, logged
  to `/var/log/lab-prebuild.log`, a failed build never fails the lab). Copy the header comment and
  the pre-build block from `dapr-pubsub/scripts/lab-setup.sh`. Extra helper scripts are
  concatenated in front of it in `lab_startup_script` (`dapr-secrets` with `seed-vault.sh`), since
  the lab's files are not on the VM.
- `website-description.md`: the prose shape (no headings; hook, what the learner does, the turn,
  what they walk away knowing).
- Explicitly **not** present: `README.md`, `tasks.hcl`, `_setup/`, `notes.md`, challenge
  `README.md`, `tabs.md`, `scripts/check*.sh`, `solve.sh`. `dapr-secrets` still carries some of
  these as leftovers. The skill says so, so nobody copies them.

### Page folders

`<n>-<slug>/assignment.md`, `<n>-<slug>/tests/challenge.robot`, and optional `<n>-<slug>/images/`.
Nothing else.

### Assignment conventions

The anatomy of a page, as the labs have it after PR #188:

1. **H1** with the page title (same as `pages.hcl`).
2. **Intro paragraph**: "In this lab, you'll … This hands-on lab takes about N minutes to complete."
   The final page starts "In this final lab, you'll …" and adds "At the end of the lab, you can claim
   the Dapr University Holopin badge for this track." (only when a badge exists).
3. **`## Before you start`** on every page after page 1 that starts its own apps: terminals and
   running apps survive page changes, so the learner checks the **Dev Dashboard** for running apps
   and stops them with `Ctrl+C` in the **Dapr CLI** window, then returns to the **Editor** tab.
   A page that keeps using the app from the previous page leaves this out and instead has a
   "Check that the application is running" section (Dev Dashboard health check) with an
   "If the application is not running" fallback that restarts it. `dapr-secrets` page 2 is the
   model. Both are valid; pick by whether the page needs a fresh app.
4. **Numbered `## N. Title` sections.**
5. **Run section pattern** (first section with Run blocks):
   - `> [!IMPORTANT]` Run-button note ("When you use the *Run* button on a command, select the
     matching terminal from the dropdown that appears.") at the top of the first section with Run
     blocks, on **every** page that has Run blocks, and before the sentence that introduces the
     first command, never between that sentence and its block.
   - An anchored `cd /root/ai-agent-tracks-instruqt/<folder>` Run block before any relative `cd`
     (doc-sync's `--require-anchored-cd` enforces this; explain why: terminals keep their folder
     across pages).
   - `> [!IMPORTANT]` "Run `dapr run -f .` from inside the demo folder of your language: …" with
     both folder spellings.
   - On page 1 only: the `> [!NOTE]` about the Editor's "Your application running on port
     `<number>` is available" popup (close or dismiss, don't click *Open in Browser*), right after
     that callout.
   - Per-language `<details>` blocks (`<summary><b>.NET</b></summary>` etc.), each naming the
     window ("Use the **Dapr CLI** window to run the commands."), with the language's own folder
     path.
   - A `###` spacer after the last `</details>`, then a `> [!IMPORTANT]` "Wait until … running"
     note that points to the **Dev Dashboard** Applications page (green dot in **Health**).
   - The expected sidecar start lines as `text,nocopy`.
6. **Commands and output**: name the window on every command ("Use the **curl** window to…").
   JSON responses are piped through `| jq` and the expected output is shown as `json,nocopy`.
   Logs are read on the **Dev Dashboard** Logs page (app drop-down plus search), not with `tail`.
7. **Callout types**: `[!IMPORTANT]` only for things the learner must do or must not skip (the
   three notes above and real preconditions). `[!NOTE]` for asides and the "expand the
   language-specific instructions" lead-in. `[!WARNING]` for a caveat such as an alpha API. Instruqt
   has no INFO type.
8. **End of a middle page**: `---`, one line saying what the learner just did, `## What's next?`,
   one line about the next lab.
9. **End of the final page**: `---`; a paragraph on what the learner proved; "Here is what you did
   in this track:" with a numbered, bold-titled line per page; `## Collect your badge & provide
   feedback` (or `## Feedback and further learning` without a badge); "Congratulations! 🎉 You've
   completed the Dapr University <topic> learning track! Click **Finish & Exit** below to finish the
   lab 🚀."; the Holopin link and the linked badge image (badge only); `## Next steps` with the bold
   sub-headings **Try another university track**, **Try these Dapr tools**, **Join the community**;
   and finally `<instruqt-completion text="You've completed <Lab title>!"></instruqt-completion>`.
   Copy the current link list from the newest lab, not from the skill.
10. **Images**: per-page `images/` folder, referenced as
    `https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/<lab>/<n>-<slug>/images/<file>.png?raw=true`,
    with descriptive alt text. Diagrams with transparent backgrounds are flattened onto white so
    the lines show on a dark theme. The images only render after merge to `main`.
11. **Badges**: created outside this repo. Leave out every badge element (main.hcl lines, intro
    sentence, badge section) until the user supplies the Holopin link and image.

### Annotations

Keep the current annotation table (`bash,run`, `text,nocopy`, `json,nocopy`, `<lang>,copy`, bare
fence) and the doc-sync rule that only `bash` fences with `run` are checked, minus the 1.0 bits
(`Instruqt-Var`, `curl,run` as an accepted alternative). The 2.0 labs write every command as
`bash,run`.

### Languages

**My call:** .NET, Python and Java is the default, because the demo repo layout, the module image
and both reference labs are built around it. The skill presents it as the default, not a rule. A
lab with fewer languages is allowed when the user asks for it; the skill then says in a short
paragraph what changes: no `<details>` blocks (or one), a single folder spelling in the "Run
`dapr run -f .`" callout, only the matching test tags, and a smaller CI matrix. A language the
image does not have (for example JavaScript) is a module change, as in "Demo apps and sandbox
content" below.

### Demo apps and sandbox content

- Demo apps live in `diagrid-labs/ai-agent-tracks-instruqt` under a folder per lab (`secrets/`,
  `pubsub/`), with `dotnet/DemoN-PascalCase/`, `python/demoN-kebab-case/` and
  `java/demoN-kebab-case/`. Each demo folder has a `dapr.yaml` Multi-App Run file and a
  `resources/` folder. New demo code goes there, never in this repo. The lab pins the commit as
  `tracks_src_ref`.
- The toolchain (Docker, Dapr CLI, .NET, JDK + Maven, Python + uv, Node, jq, git, code-server,
  Dev Dashboard) comes from the module image. Anything a new lab needs that is not in the image
  (a tool, or a container image to pre-pull such as RabbitMQ) is a module change: image rebuild,
  new module version, publish, then pin. The skill must flag this as an owner-dependent step and
  point to "Toolchain bump" in the runbook, because it is the slowest part of creating a lab.
- A container the learner starts on a page (RabbitMQ) is started from that page's Run block, not
  in `lab-setup.sh`, unless the lab needs it from page 1 (Vault).
- Secrets / API keys: keep the existing rule (learner supplies it on page 1 via `.env` or `export`,
  never baked in, announced in the description). Without page checks there is no `check.sh` to
  validate it; the page tells the learner how to verify it instead. Mark this as untested in 2.0,
  since neither reference lab needs a key.

### Drift tests and CI for a new lab

What a new lab adds, each modelled on the `dapr-pubsub` equivalent:

- `<n>-<slug>/tests/challenge.robot` per page with Run blocks: per-language test cases tagged
  `dotnet`/`python`/`java`, an untagged "ports are free" test, `[Teardown] Stop Process With
  SIGINT`, `Documentation`, `${LOG} ${TEMPDIR}/<lab>-ch<n>.log`, and the trailing
  `# doc-sync coverage (<why>):` block. Keep the existing conventions section.
- `tools/track-tester/variables/<lab_with_underscores>.py` (resolves `TRACKS_SRC_DIR`, defines the
  base path and per-language folder names).
- `tools/track-tester/ci/setup-<lab>.sh` (reads pins with `read_pin.py`, clones the demo at
  `tracks_src_ref`, installs the Dapr CLI, inits Dapr, plus lab-specific services).
- `.github/workflows/test-<lab>.yml` copied from `test-dapr-pubsub.yml`: `changes` path gate,
  doc-sync job with `--require-anchored-cd`, language matrix plus `shared` leg, aggregate
  `<lab>-result` job, `report` job, next free cron slot (look it up in the existing workflows).
- Add the lab to the loops in `.github/workflows/lab-validate.yml` (format, validate, shellcheck).
- A pytest under `tools/track-tester/ci/tests/` for any value that must agree across files (model:
  `test_pubsub_pins.py`).
- Docs: the track table and CI table in `AGENTS.md`, and the workflow table in the repo
  `README.md`.

### Local validation (what the agent runs before saying done)

- `tools/track-tester/ci/validate-lab.sh <lab> modules/dapr-sandbox`
- `instruqt lab format` check and `check_lab_paths.py`, as `lab-validate.yml` runs them
- shellcheck on `scripts/*.sh`
- doc-sync with `--require-anchored-cd` for every page
- `uv run robot --dryrun` on all suites, then a real run after `ci/setup-<lab>.sh` when Docker is
  available
- `uv run pytest` in `tools/track-tester`
- the per-page minutes add up to the "around N minutes" line, rounded down, under the time limit

### Owner hand-off

The skill ends with a short list of what only the repo owner can do, pointing to
`docs/instruqt-2-runbook.md` (the "Checkpoint B: dapr-pubsub lab" section is the model) instead of
copying it: publish a new module version if the image changed, create the lab in Instruqt
connected to `main` with the lab folder as root directory, add `<lab>-result` to the required
checks, do a timed play-through, create the Holopin badge, embed the lab. The agent's job is to
tell the user these steps are pending, not to do them.

### Common mistakes and checklist

Rewrite both for 2.0. The mistakes table at least covers: creating any 1.0 file; copying the
leftover 1.0 files in `dapr-secrets`; no H1 or a mismatched H1; a relative `cd` before an anchored
one; the Run-button note missing on a page or placed between a sentence and its block; IMPORTANT
used for background information; a page after page 1 that starts its own apps without a
`## Before you start`, or that reuses the previous page's app without the "is it running" check;
a page that starts a
service in `lab-setup.sh` that only one later page needs; pinning an unpublished module version;
copying a pin into a second file; a tab that is not visible on a page whose Run blocks target it; a
new lab not added to `lab-validate.yml`; inventing a badge link; sizing copied from `dapr-pubsub`.

## Decisions left to the builder

- Exact wording and section order inside each file, and how detail is split between `SKILL.md` and
  `reference.md`, as long as `SKILL.md` stays readable in one pass.
- Whether templates are shown in full or as "copy this file from `dapr-pubsub` and change X, Y, Z".
  Prefer the second for long HCL and shell files, since the files themselves are the source of
  truth.
- How much of the existing 1.0 text is trimmed when it moves into `legacy-1.0.md`. Moving it with
  light edits is fine.

## Out of scope, follow-up

Found while reading for this spec. List them in the PR description; don't fix them in this change:

- `dapr-secrets/` still contains `README.md`, `_setup/`, and per-challenge `README.md`, `notes.md`,
  `tabs.md` and `scripts/setup.sh`. They no longer drive the lab.
- `AGENTS.md`'s harness directory map (around line 185) still lists `test_secrets_checks`,
  `test_pubsub_checks` and `test_pubsub_lib_checks`, which no longer exist.
- `dapr-pubsub/1-subscription-types/assignment.md` says "on a later lab" where "in a later lab" is
  meant.

## Acceptance

- `grep` over `SKILL.md` and `reference.md` finds no instruction to create `README.md` config,
  `notes.md`, `tabs.md`, `_setup/`, `tasks.hcl`, `check.sh`, `solve.sh` or `Instruqt-Var`.
- Every rule in "Content the skill must teach" appears in `SKILL.md` or `reference.md`.
- A dry run: a fresh agent given only the updated skill and the request "scaffold a 3-page dapr-state
  lab" lists the files and steps that match the `dapr-pubsub` layout and CI wiring, and names the
  owner steps as pending. (This is a reading test of the plan the agent proposes, not a full build.)
