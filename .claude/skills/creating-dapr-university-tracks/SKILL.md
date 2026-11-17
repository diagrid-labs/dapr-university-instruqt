---
name: creating-dapr-university-tracks
description: Use when creating, scaffolding, or adding to a Dapr University track (a new lab, a new page, or a new lab folder) for Instruqt in this repo. New tracks are Instruqt 2.0 labs on the shared diagrid/dapr-sandbox module — covers the HCL config (main.hcl, pages.hcl, layouts.hcl, tabs.hcl, versions.hcl), scripts/lab-setup.sh, assignment.md page anatomy and Instruqt annotations, demo apps, Robot Framework drift tests and CI, local validation and the owner's Instruqt steps. Also use it for editing the legacy 1.0 tracks.
---

# Creating Dapr University tracks

## Overview

A Dapr University **track** is a self-paced, browser-based Dapr course on [Instruqt](https://instruqt.com/),
launched from [Dapr University](https://www.diagrid.io/university). New tracks are **Instruqt 2.0
labs**: a top-level folder with HCL config, one folder per page, and the shared
`diagrid/dapr-sandbox` module (`modules/dapr-sandbox/`) for the VM. **`dapr-pubsub` and
`dapr-secrets` are the reference labs.** Open them while you work; they are the source of truth, and
this skill describes them.

A 2.0 lab has **no page checks**: no `tasks.hcl`, no check or solve scripts. A learner can move to
the next page at any time, and the Robot Framework drift suites test each page instead.

Rules owned elsewhere, not repeated here: pins, required checks and `lab-validate` in `AGENTS.md`
("Instruqt 2.0 labs"); the owner's Instruqt UI steps in `docs/instruqt-2-runbook.md`; schema facts
in `docs/instruqt-2-spike-checklist.md`; the module in `modules/dapr-sandbox/README.md`.

Editing one of the older tracks (`dapr-101`, `dapr-workflow`, `dapr-workflow-aspire`, the agent and
AI tracks, `catalyst-101`)? Those are legacy 1.0 tracks: follow `legacy-1.0.md` in this folder.

Detail and templates for everything below: **reference.md** in this folder.

## Terminology

Learner-facing text calls the whole course the **track** and each page a **lab**: "This hands-on lab
takes about 7 minutes to complete", "In the next lab you'll…", "complete the 4 labs". Instruqt's
config uses different words: the whole thing is a `lab` resource, which holds a `chapter` with
`page` entries. So "lab" means a page to the learner and the whole course in HCL. "Challenge" is a
1.0 word; page folders are still `<n>-<slug>/` and suites are still named `Ch<n>`.

## Sizing

- **3 to 5 pages**, about **5 to 8 minutes** each.
- `main.hcl` settings as in `dapr-secrets`: `timelimit { duration = "30m" extend = "10m" show_timer = true }`
  and `idle { enabled = true timeout = "10m" show_warning = true }`.
- The `main.hcl` line "You'll probably need around N minutes to complete the M labs." is the sum of
  the per-page estimates, **rounded down to a multiple of 5** (`dapr-secrets`: 28 → 25,
  `dapr-pubsub`: 42 → 40), under the time limit.
- Ask the user before going over 5 pages or 30 minutes. `dapr-pubsub` (6 pages / 45 minutes) is an
  approved exception, not a precedent.

## Lab layout

```
<lab>/                         e.g. dapr-pubsub/
  main.hcl                     the lab resource: title, description, settings, chapter and pages
  pages.hcl                    one page resource per page (title + file)
  layouts.hcl                  instructions left; Dev Dashboard + Editor tabs; Dapr CLI + curl terminals
  tabs.hcl                     the editor and dev_dashboard services, the dapr_cli and curl terminals
  versions.hcl                 lab pins + the module "sandbox" block (exact version)
  scripts/lab-setup.sh         only this lab's own boot steps (pre-build, seeding)
  website-description.md       prose for the Dapr University site
  README.md                    optional human file map (dapr-secrets has one); not config
  <n>-<slug>/
    assignment.md              the page the learner reads
    tests/challenge.robot      the drift suite for this page
    images/                    optional diagrams and the badge
```

A 2.0 lab never has a track or page `README.md` used as config, `notes.md`, `tabs.md`, `_setup/`,
`tasks.hcl`, `scripts/check*.sh` or `solve.sh`. Those are 1.0 files; do not create them.

Demo apps are **not** in this repo. They live in `diagrid-labs/ai-agent-tracks-instruqt` under one
folder per lab (`secrets/`, `pubsub/`), and the lab pins the commit as `tracks_src_ref`.

## Workflow

1. **Scope with the user**: title, folder name, languages (default .NET, Python and Java), the one
   concept each page teaches, and whether the lab needs anything the sandbox image lacks (a tool,
   a container image). That last one is a module change and the slowest part; see reference.md →
   Demo apps and sandbox content. Use `superpowers:brainstorming` when the outline is open.
2. **Study `dapr-pubsub`** (and `dapr-secrets` for a lab that seeds a service at boot). Copy the
   closest files and adapt them.
3. **Demo apps**: add them to `ai-agent-tracks-instruqt`, one demo folder per page or concept, each
   with `dapr.yaml` and `resources/`. Pin the commit.
4. **Root files**: `main.hcl`, `pages.hcl`, `layouts.hcl`, `tabs.hcl`, `versions.hcl`,
   `scripts/lab-setup.sh`, `website-description.md`. See reference.md → Root files and
   lab-setup.sh.
5. **Pages**: one `<n>-<slug>/assignment.md` each, following reference.md → Page anatomy.
6. **Drift tests and CI**: a suite per page, the variables file, the CI setup script, the workflow,
   the `lab-validate.yml` loops and the docs tables. See reference.md → Drift tests and CI.
7. **Validate locally**: reference.md → Local validation. Run every command; don't eyeball.
8. **Hand off**: tell the user which owner steps are pending (reference.md → Owner hand-off).
   Don't claim the lab is live.

To **add a page** to an existing lab: a new `<n>-<slug>/` folder, a `pages.hcl` resource, a `page`
entry and a learn bullet in `main.hcl`, a suite, the page added to the doc-sync and suite lists in
`test-<lab>.yml`, a `DEMO<n>` dict in the variables file, the new demo in the `lab-setup.sh` prebuild
list, a line in the final page's recap, the minutes line updated (and `timelimit` if the sum passes
it, after asking), and the "What's next?" of the previous page pointing at it. A page added after
the current final page takes over the final-page intro and closing; the old final page gets a normal
close. The module and `versions.hcl` stay as they are unless the page needs a new demo
commit or something the image lacks.

## Assignment quick reference

Every page: an **H1** equal to its `pages.hcl` title; an intro ending "This hands-on lab takes
about N minutes to complete."; numbered `## N. Title` sections; `---` and a close. Full anatomy,
including the final page, in reference.md → Page anatomy.

**Annotations.** Ask: does the learner execute it, paste it, or only read it?

| Fence | Use on | Effect |
|---|---|---|
| `` ```bash,run `` | A command the learner runs. The 2.0 labs write every command this way | Run button; doc-sync checks it |
| `` ```text,nocopy `` / `` ```json,nocopy `` | Expected output, logs, JSON responses | No button |
| `` ```<lang>,copy `` | Code or config the learner pastes into a file | Copy button |
| `` ```yaml,nocopy `` | A fragment the learner only reads | No button (a bare fence still gets a Copy button) |

A `bash,run` block is a promise: doc-sync requires the command in the page's suite. Pipe JSON
responses through `| jq` and show the result as `json,nocopy`.

**Callouts.** `> [!IMPORTANT]` only for what the learner must do or must not skip. `> [!NOTE]` for
asides. `> [!WARNING]` for a caveat such as an alpha API. Instruqt has no INFO type.

**The run section** (the first section with Run blocks, on every page that has them):

1. `[!IMPORTANT]` "When you use the *Run* button on a command, select the matching terminal from the
   dropdown that appears." at the top of the section, before the sentence that introduces the
   first command.
2. A Run block `cd /root/ai-agent-tracks-instruqt/<folder>` before any relative `cd`. Terminals
   keep their folder across pages, and doc-sync's `--require-anchored-cd` enforces this.
3. `[!IMPORTANT]` "Run `dapr run -f .` from inside the demo folder of your language: …" with both
   folder spellings. On page 1 only, the `[!NOTE]` about the Editor's port popup follows it.
4. One `<details>` block per language, each naming the window and its own folder.
5. `###`, then `[!IMPORTANT]` "Wait until … running" pointing to the **Dev Dashboard** Applications
   page, then the expected sidecar lines as `text,nocopy`.

Name the window on every command ("Use the **curl** window to…"). Read logs on the Dev Dashboard
Logs page.

**Pages after page 1**: terminals and running apps survive page changes. A page that starts its own
apps opens with `## Before you start` (check the Dev Dashboard, stop running apps with `Ctrl+C`). A
page that keeps the previous page's app opens with a "Check that the application is running"
section with a restart fallback (`dapr-secrets` page 2).

## Languages

.NET, Python and Java is the default: the demo repo layout, the image and both reference labs are
built around it. Folder names follow each language: PascalCase for .NET (`dotnet/Demo1-ReadSecret`),
kebab-case for Python and Java (`python/demo1-read-secret`). A lab with fewer languages is fine when
the user asks: fewer or no `<details>` blocks, one folder spelling in the callout, only the matching
test tags and CI matrix legs. A language the image lacks is a module change.

## Common mistakes

| Mistake | Fix |
|---|---|
| Creating any 1.0 file (`README.md` config, `notes.md`, `tabs.md`, `_setup/`, `tasks.hcl`, check or solve scripts) | Not in a 2.0 lab. Config is HCL; tests are the Robot suites. |
| No H1, or an H1 that differs from the `pages.hcl` title | Same text in both. |
| A relative `cd` before the anchored `cd /root/ai-agent-tracks-instruqt/<folder>` | Anchor first; doc-sync `--require-anchored-cd` fails otherwise. |
| The Run-button note missing on a page, or placed between a sentence and its block | Top of the first section with Run blocks, on every such page. |
| `[!IMPORTANT]` for background information | Use `[!NOTE]` or `[!WARNING]`. |
| A later page that starts apps with no `## Before you start`, or reuses an app with no "is it running" check | Pick one of the two openings. |
| Starting a service in `lab-setup.sh` that only one later page needs | Start it from that page's Run block (RabbitMQ on `dapr-pubsub` page 6). |
| A container image the sandbox image doesn't pre-pull (pulled on the learner's clock or at boot) | Add it to `modules/dapr-sandbox/scripts/prewarm.sh`: a module change and an owner step. |
| Pinning a module version that is not published in Instruqt | Publish first; the sync fails until then. |
| Copying a pin into a second file | Each pin lives in one `versions.hcl`; CI reads it with `read_pin.py`. |
| A terminal or tab that is not visible on a page whose Run blocks target it | Run buttons only reach visible terminals. Keep both terminals in the bottom row. |
| A new lab missing from `lab-validate.yml` | Add it to the format, referenced-files (`check_lab_paths.py`), validate and shellcheck loops. |
| Inventing a Holopin badge link | Badges are made outside the repo. Leave every badge element out until the user supplies one. |
| Copying `dapr-pubsub`'s 6 pages / 45 minutes | Default is 3 to 5 pages and 30 minutes. Ask first. |
| Volatile values copied from this skill | Copy versions, SHAs and links from the newest lab, not from here. |

## Checklist

- [ ] `main.hcl`: description (learn bullets, rounded-down minutes line, sandbox line, badge lines
      only with a badge), settings, layout, one chapter, one `page` entry per page
- [ ] `pages.hcl` titles equal the page H1s; `layouts.hcl` and `tabs.hcl` copied from `dapr-secrets` (no `broker` layout or `rabbitmq` service)
- [ ] `versions.hcl`: `dapr_runtime_version`, `tracks_src_ref`, `module "sandbox"` with an exact,
      published version and the inputs
- [ ] `scripts/lab-setup.sh`: only the lab's steps, safe to re-run, background pre-build
- [ ] `website-description.md` in prose
- [ ] 3 to 5 page folders, each with `assignment.md` and `tests/challenge.robot`; minutes add up
- [ ] Every page follows the page anatomy; the final page closes with recap, badge/feedback, next
      steps and `<instruqt-completion>`
- [ ] Every command `bash,run` and covered by its suite; every output block `,nocopy`
- [ ] `tools/track-tester/variables/<lab_with_underscores>.py`, `tools/track-tester/ci/setup-<lab>.sh`,
      `.github/workflows/test-<lab>.yml`, the `lab-validate.yml` loops, the lab in the parametrize
      lists of `tools/track-tester/ci/tests/test_read_pin.py`, a pin-agreement pytest where other
      values must match across files
- [ ] `AGENTS.md` track and CI tables and the repo `README.md` workflow table updated
- [ ] Local validation passed (reference.md → Local validation)
- [ ] Owner steps listed for the user as pending
