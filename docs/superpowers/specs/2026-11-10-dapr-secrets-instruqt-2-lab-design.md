# Dapr Secrets as an Instruqt 2.0 lab, plus a shared Dapr sandbox module

Status: draft for review · Date: 2026-11-10

## Why

Lesson content lives in this repo, but getting it into Instruqt is manual: track config,
challenge config and `assignment.md` content are copy-pasted into the Instruqt web UI. That is
slow, error-prone, and means the repo and the live track can silently differ.

Instruqt 2.0 ("labs") is lab-as-code: a lab is a folder of HCL plus Markdown, connected to a
GitHub repo, and **every push to the connected branch deploys** (there is no publish command).
2.0 went GA on 2026-09-29 and is the default platform; legacy tracks are supported until
2027-09-27. `dapr-secrets` is brand new and not yet in Instruqt, so it is the proof of concept:
build it natively in 2.0 instead of creating one more legacy track that must be migrated within a
year.

The second part is a **shared sandbox module** with the toolchain every Dapr University track
needs, so future labs (and later migrations of the existing tracks) reuse one definition instead
of each track maintaining its own VM image script.

## Goals

1. `dapr-secrets` runs on Instruqt 2.0 as a lab whose **only source is this repo**. A merged PR
   reaches learners with no manual step in the Instruqt UI (after the one-time import).
2. A shared sandbox module, `dapr-sandbox`, that provides an Ubuntu VM with:
   - Docker Engine (required by `dapr init` and the Vault container)
   - .NET SDK (10)
   - Python (3.12) + uv (on the default `PATH` of every terminal)
   - Java JDK (17) + Maven
   - Node.js (current LTS) + npm
   - Dapr CLI
   with versions set through module variables.
3. Maximum automation around it:
   - CI validates and format-checks all lab and module HCL on every PR.
   - The existing `track-tester` drift tests keep running for `dapr-secrets` unchanged in
     behaviour.
   - Every version pin (Dapr CLI, Dapr runtime, demo repo ref, toolchain versions) lives in
     exactly one place and CI reads it from there.
   - PR branches can be played as preview labs before merge.
4. Learner experience equal to the current design of the track: same four challenges, same
   instructions, same three tabs (Editor, Dapr CLI terminal, curl terminal), same checks on
   challenges 3 and 4, 30-minute time limit.

## Non-goals

- Migrating the other tracks (`dapr-101`, `dapr-workflow`, …). The module is designed for them,
  but moving them is follow-up work.
- Rewriting assignment content beyond what 2.0 rendering forces.
- Changing the demo apps in `diagrid-labs/ai-agent-tracks-instruqt` (except possibly tagging a
  release to pin to).
- Rewriting the Robot Framework suites or the doc-sync checker.
- A local "play the lab" path. Labs are played on Instruqt.
- Changing how learners reach tracks. Lessons are embedded on the Diagrid University site today
  and `dapr-secrets` will be embedded the same way. Gated access via a HubSpot form that forwards
  to the lab is a separate follow-up plan.

## Anti-goals (would be a failure even if it technically works)

- The Instruqt web UI becomes a second place where content is authored. UI publishes commit back
  to git, so it is technically synced, but the workflow must be "edit in repo, push".
- A version pinned in more than one place (HCL and a script and a workflow file).
- A sandbox that starts noticeably slower than the legacy custom image (cold package caches,
  installing the whole toolchain at every launch without a decision to accept that).
- A credential (e.g. the Docker Hub PAT) exposed to learners. Instruqt docs warn that values in
  a VM's `environment` map are readable by anyone with terminal access.
- Breaking the existing CI (`test-dapr-secrets.yml`) or the doc-sync job.

## Current state (what exists today)

`dapr-secrets/` uses this repo's custom format:

| File | Purpose today |
| --- | --- |
| `README.md` | Track config as Markdown headings (name, slug, teaser, time limit, idle timeout, extra time) |
| `website-description.md` | Copy for the Diagrid University website |
| `_setup/image-dapr-secrets-install.sh` | Builds the legacy custom VM image (`dotnet-10-aspire` host): Docker, .NET 10, JDK 17 + Maven, Python 3.12 + uv, Dapr CLI, and pre-warms NuGet/Maven/uv caches by building all demos |
| `_setup/sandbox-setup.sh` | Runs at every launch: clones the demo repo, `docker login`, pins `DAPR_CLI_VERSION`/`DAPR_RUNTIME_VERSION` via `agent variable set`, `dapr init`, writes `secrets.json`, starts and seeds Vault, pre-builds Demo1 |
| `N-slug/README.md` | Challenge title, slug, description |
| `N-slug/tabs.md` | Tabs: Editor (code editor), Dapr CLI (terminal), curl (terminal), all on host `dotnet-10-aspire`, path `ai-agent-tracks-instruqt/secrets` |
| `N-slug/assignment.md` | Learner instructions (uses `bash,run`, `yaml,copy`, `> [!IMPORTANT]`/`> [!NOTE]` alerts, `<details><summary>` per-language sections) |
| `N-slug/notes.md` | Author notes |
| `N-slug/scripts/setup.sh` | Per-challenge setup (all four): makes the challenge self-sufficient when started out of order |
| `N-slug/scripts/check.sh`, `solve.sh` | Challenges 3 and 4 only. Checks use the legacy `fail-message` command with dynamic text |
| `N-slug/tests/challenge.robot` | Drift tests |

CI: `.github/workflows/test-dapr-secrets.yml` runs doc-sync plus a dotnet/java/python/shared
matrix. `tools/track-tester/ci/setup-dapr-secrets.sh` syntax-checks `sandbox-setup.sh` and
**awk-parses the two pinned Dapr versions out of it** (`agent variable set NAME VALUE` lines).

## Target design

### Repository layout

```
modules/
  dapr-sandbox/                 shared sandbox module (its own Instruqt root)
    main.hcl                    variables, VM resource, outputs
    scripts/install-tools.sh    single install script for the whole toolchain
    README.md                   what it provides, variables, outputs, how to publish
dapr-secrets/                   lab root (Instruqt "root directory" = dapr-secrets)
  main.hcl                      resource "lab": title, description, layout, settings, chapters/pages
  versions.hcl                  every pin for this lab (see "Version pins")
  sandbox.hcl                   module "sandbox" + lab-specific setup
  layouts.hcl                   instructions column + Editor / Dapr CLI / curl tabs
  tabs.hcl                      terminal and editor resources
  pages.hcl                     one page per challenge, file = "N-slug/assignment.md"
  tasks.hcl                     tasks for challenges 3 and 4
  scripts/                      lab-level scripts (lab setup, Vault seeding)
  README.md                     human readme (no longer Instruqt config)
  website-description.md        unchanged
  1-what-is-the-secrets-api/ … 4-swap-the-provider/
    assignment.md               unchanged path; edited only where 2.0 rendering needs it
    notes.md                    kept as author notes (not deployed content, see below)
    scripts/                    setup/check/solve adapted to 2.0
    tests/challenge.robot       unchanged
```

Decided: the challenge folders keep their current paths, and `pages.hcl` points each page at the
existing `assignment.md`. This keeps the Robot suites, the doc-sync checker, the CI paths and the
authoring skill working with minimal change.

### The shared module (`modules/dapr-sandbox`)

- One VM resource based on Instruqt's `ubuntu:24.04`, `x86_64`, sized for building .NET, Java
  and Python demos side by side plus Docker. Sizing is a module variable with defaults (builder's
  call on the defaults; the legacy host is the reference).
- `scripts/install-tools.sh` installs Docker Engine, .NET SDK, Python + venv/pip, uv into
  `/usr/local/bin`, JDK + Maven, Node.js LTS, and the Dapr CLI at the requested version, then
  prints all versions and fails loudly if any are missing. Derived from
  `_setup/image-dapr-secrets-install.sh`, minus the demo-specific cache pre-warm.
- Toolchain versions are pinned inside the module (see "Version pins"), not passed in by labs.
  Lab-facing variables are limited to things a lab can really change at launch, such as `cpu`
  and `memory`. Python stays at the distro's 3.12 unless the builder finds a reason not to.
- Outputs: whatever a lab needs to target the VM from terminals, editor tabs, tasks and exec
  (the VM reference/id), plus the resolved tool versions if outputs make that easy.
- Does **not** run `dapr init`, clone repos, or do anything track-specific. Labs do that.
- Distribution: published to the Instruqt module registry as `diagrid/dapr-sandbox` (Instruqt
  team slug: `diagrid`) and consumed by labs with an exact version (see "Version pins"). If the spike shows a registry module cannot be published from git, or
  that a local module outside the lab root is supported, the builder picks the most automated
  option and records why.

### Startup speed: custom image (decided)

- **Maximum wait: 1 minute 30 seconds** from "start lab" until the learner can use the first page
  (sandbox ready, lab setup finished). This is a hard requirement.
- The module's VM uses a **custom image built with Instruqt's Image Builder** from
  `modules/dapr-sandbox/scripts/install-tools.sh`. Rebuilding the image **by hand** in the
  Instruqt UI is accepted (decided by the track owner), as long as the repo holds exact,
  step-by-step rebuild instructions (see "Admin runbook").
- The image name/version the module uses is pinned in `modules/dapr-sandbox/versions.hcl`, next
  to the toolchain versions it was built with, so a toolchain bump in a PR always shows the
  matching image bump.
- Cache pre-warm (my call): to meet 1:30, the image also warms the NuGet, Maven and uv caches by
  building the Dapr University demo apps once (as `image-dapr-secrets-install.sh` does today), in
  a separate `scripts/prewarm.sh` with the list of demo folders, so the toolchain script stays
  generic. Pre-pulling the Dapr, Redis, Zipkin and Vault container images into the image is also
  wanted if the Docker daemon runs during an image build (spike item).
- `startup_script`-only installs are the fallback only if the Image Builder cannot build this
  image at all; it will almost certainly miss 1:30.
- Hot starts (pre-warmed sandboxes) are **not** part of the steady-state design. They may be
  used temporarily around a new track's launch; that is an ops decision, not something to
  configure in this work.

### Lab-specific setup

What `_setup/sandbox-setup.sh` does today still has to happen at launch, in an idempotent script
under `dapr-secrets/scripts/`:

1. Clone `diagrid-labs/ai-agent-tracks-instruqt` at the **pinned ref** to
   `~/ai-agent-tracks-instruqt` (same path as today; assignments, tests and tabs rely on it).
2. `dapr init` with the pinned runtime version, guarded so a re-run does not recreate containers.
3. Write `secrets.json` from `secrets.example.json`.
4. Start Vault dev mode (`hashicorp/vault:1.20`) and seed it from `secrets.json`.
5. Pre-build the demo apps (Demo1, then Demo2) in all three languages in a detached background
   job, so the sandbox reports ready without waiting for the builds. (Changed 2026-11-10 by the
   track owner: start-up time comes first; a learner who runs `dapr run` before a build has
   finished only waits for that build.)

How it runs on a VM is for the builder to settle in the spike: `exec` only targets containers, so
the candidates are a module variable that appends a lab script to the VM's startup, or a setup
script on the first task/page. Sandbox creation must not report ready before steps 1 to 4 finish.
The script logs each step with a timestamp to `/var/log/lab-setup.log` on the VM, because the
lab Logs only show its output once it has ended.

Docker Hub login: today `docker login` uses `DockerUSER`/`DockerPAT`. In 2.0, a secret passed via
a VM's `environment` is readable by learners. The builder must either avoid the login (pre-pull
`daprio/*`, `redis`, `openzipkin/zipkin` and `hashicorp/vault` into the image in option A, or
show anonymous pulls are fine) or pass the PAT only to the setup step without leaving it in the
learner's environment. Exposing it in the VM env is not acceptable.

### Pages, tabs, tasks

- One chapter, four pages in challenge order, titles from each `N-slug/README.md`.
- Layout: instructions column + tabs **Editor** (code editor), **Dapr CLI** (terminal),
  **curl** (terminal), all on the module's VM, working directory
  `~/ai-agent-tracks-instruqt/secrets`. If 2.0 has no code-editor tab type, use the closest
  equivalent and note it.
- Tasks for challenges 3 and 4 from `check.sh`/`solve.sh`, embedded with
  `<instruqt-task id="...">` in the assignment at the point where the learner is asked to check.
  The legacy `fail-message` command gives dynamic, cause-specific hints; 2.0 has a static
  `failure_message` per condition. Keep the specific hints by splitting each check into several
  conditions (one per cause), unless the spike shows script output can be shown to the learner.
- Per-challenge `setup.sh` (self-sufficiency when a learner jumps ahead): keep the behaviour if
  2.0 offers a page/task setup hook; otherwise fold it into the lab setup and note that jumping
  ahead relies on it.
- The final page ends with `<instruqt-completion>` and the feedback block, replacing the legacy
  "rate this training in the next step" wording.
- Lab settings: time limit 30 min, idle timeout 10 min, extra time 10 min where 2.0 supports
  them. The teaser has no 2.0 field; it stays in `website-description.md`.
- `notes.md` files stay in the repo as author notes. The builder may map them to the 2.0 notes
  tab if it renders sensibly, otherwise leave them undeployed.

### Markdown compatibility

The `bash,run`, `yaml,copy`, `nocopy` and `wrap` fence flags are the same in 2.0. Two things are
undocumented and must be checked by rendering a page in the spike:

- `> [!IMPORTANT]` / `> [!NOTE]` alerts.
- `<details><summary>` language sections.

If either does not render, convert to the 2.0 equivalent (alert blocks; `<instruqt-code-group>`
tabs or another collapsible) **and** update `docsync/check_doc_sync.py` if its `<summary>`
language mapping is affected, with unit tests.

### Version pins (single source of truth)

Pins are split by owner (my call), each with one fixed `name = "value"`-per-line file that awk
can read:

- **Toolchain pins belong to the module**, in `modules/dapr-sandbox/versions.hcl`: .NET SDK,
  JDK, Node, Dapr CLI. With a custom image (option A) these versions are baked in at image build
  time, so lab-time variables could not change them anyway. Bumping one means a new image and a
  new module version. Under option B the same file drives `startup_script`. The module does not
  expose these as lab-overridable variables, so there is no variable that silently does nothing.
- **Lab pins belong to the lab**, in `dapr-secrets/versions.hcl`:
  - the `dapr-sandbox` module version (exact version, not a range, so a lab never changes
    under a learner without a commit)
  - `dapr_runtime_version` (used by `dapr init --runtime-version` in the lab setup)
  - `tracks_src_ref` (tag or commit of `ai-agent-tracks-instruqt`)

Consumers:

- the lab HCL (passed into the module and the lab setup script via `environment`, since scripts
  are not templates),
- `tools/track-tester/ci/setup-dapr-secrets.sh`, which today parses `sandbox-setup.sh` and must
  now read `DAPR_CLI_VERSION` from the module's `versions.hcl` and `DAPR_RUNTIME_VERSION` from
  the lab's; it also clones the demo repo at `tracks_src_ref` instead of `main`,
- the `[[ Instruqt-Var ]]` replacement, if any assignment needs to display a version (none does
  today).

Pinning the demo repo is a behaviour change: drift tests then catch drift in the toolchain and
Dapr, while demo-repo changes arrive by bumping the ref in a PR. That is intended.

### Git connection and deploy flow (decided)

- The lab is connected to **`main`**. All changes to this repo go through a PR, and `main` gets
  **required status checks** (the validate/fmt job and the dapr-secrets drift jobs), so a merge is
  the deploy and nothing reaches `main` unchecked.
- PR branches are playable as preview labs if Instruqt picks up pushed branches; the spike
  confirms this and the runbook describes how to open one.
- A lab connected below the repo root cannot be disconnected later. Accepted.

### Admin runbook (deliverable)

The track owner has Instruqt admin and GitHub admin rights and does every Instruqt-side and
repo-settings step by hand, so the builder must deliver **`docs/instruqt-2-runbook.md`**: exact,
numbered, click-by-click instructions (menu names, field values, what success looks like) for:

1. Installing/authorizing the Instruqt GitHub App for `diagrid-labs/dapr-university-instruqt`
   (Integrations → Version control).
2. Building the `dapr-sandbox` image in the Image Builder from `install-tools.sh` +
   `prewarm.sh`, naming/versioning it, and updating `modules/dapr-sandbox/versions.hcl` in a PR.
   Also the **rebuild** procedure for a toolchain bump.
3. Publishing the `diagrid/dapr-sandbox` module (first version and later versions).
4. Creating any team secrets (Building blocks → Secrets).
5. Importing the lab: Labs → Import lab → this repo → branch `main` → root directory
   `dapr-secrets`.
6. Playing a preview branch, and running the end-to-end acceptance play-through (all four pages,
   in each of .NET, Python and Java), including timing the start against the 1:30 limit.
7. Setting required status checks on `main` (GitHub → repo Settings → Rules → Rulesets, or
   Settings → Branches → branch protection rule for `main` → "Require status checks to pass",
   selecting the job names from the workflows).
8. Creating the `INSTRUQT_TOKEN` repo secret if the optional `instruqt lab test` job is added.
9. Getting the embed for the 2.0 lab to replace the current embed on the Diagrid University
   site.

The Phase 0 spike is also run by the track owner from a checklist the builder writes (expected
result per item, and where to record findings in this spec).

### CI automation

New job(s), in `test-dapr-secrets.yml` or a new `lab-validate.yml` that runs on any `**/*.hcl`
or `modules/**` change:

- Install the Instruqt CLI (pinned version; Linux release zip from `instruqt/cli`).
- `instruqt lab fmt` on each lab and module, failing if it changes anything.
- `instruqt lab validate` on `dapr-secrets/` and `modules/dapr-sandbox/`.
- Script hygiene: `bash -n` (and `shellcheck` if cheap) on all lab and module scripts, replacing
  the current `bash -n sandbox-setup.sh` step.
- Optional, behind an `INSTRUQT_TOKEN` repo secret: a scheduled `instruqt lab test <team>/<lab>`
  run against the deployed lab, reporting into the existing `drift-report` issue.

Existing drift jobs keep running. Their setup script changes only in where it reads the pins and
which demo ref it clones.

### Docs and tooling to update

- `AGENTS.md`: 2.0 lab layout, `modules/`, version pins, deploy flow, `dapr-secrets` as the first
  2.0 lab.
- `.claude/skills/creating-dapr-university-tracks`: new tracks are 2.0 labs; how to use the module.
- Remove the legacy-only files from `dapr-secrets/` (`_setup/`, `tabs.md`, per-challenge
  `README.md` once their content is in HCL) **after** the lab has been played end to end.

## Phase 0: spike (do first, record findings in this file)

Each item is a yes/no to settle before building the rest:

1. Install the CLI and run `instruqt lab init` in a scratch dir to get the real scaffold and HCL
   schema; confirm `lab validate`/`lab fmt` work in CI without auth.
2. Docker Engine inside a 2.0 VM: `dapr init` and `docker run hashicorp/vault` work.
3. Image Builder: can it build an image from `install-tools.sh` + `prewarm.sh`, and does the
   Docker daemon run during the build (for pre-pulling container images)?
4. Modules: can a module be published from git/CLI? Can a lab use a local module outside its
   root directory?
5. How to run a lab-level setup script on a VM before the sandbox reports ready.
6. Do `> [!NOTE]` alerts and `<details>` sections render?
7. Is there a code-editor tab type?
8. Can a task show script output, or only the static `failure_message`? Do pages/tasks have a
   setup hook?
9. Do pushed non-default branches appear as playable preview labs?
10. Does a launch with the custom image plus lab setup finish within 1:30? If not, what moves
    into the image.
11. How is a 2.0 lab embedded on an external site?

## Success criteria

- Merging a PR that changes a `dapr-secrets` assignment updates the live lab with no Instruqt UI
  step.
- A learner can play all four pages end to end in .NET, Python and Java; checks on pages 3 and 4
  pass when done right and give the specific hints when not.
- `test-dapr-secrets.yml` is green, including the new validate/fmt job.
- Every version pin appears in exactly one file.
- No credential is readable from a learner terminal.
- A second lab could use `dapr-sandbox` by adding one `module` block.
- The lab is ready for the learner within 1 minute 30 seconds of starting.
- The lab can be embedded on the Diagrid University site like the current tracks.
- The track owner completed every Instruqt-side step using only `docs/instruqt-2-runbook.md`.

## Left to the builder

- Exact HCL, resource names, VM sizing defaults, Node LTS version, file split across `*.hcl`.
- Whether the new CI job lives in the existing workflow or a new one.
- How check scripts are split into conditions, as long as the hints keep their specificity.
- Mapping of `notes.md`.
