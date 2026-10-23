---
name: creating-university-tracks
description: Use when creating, scaffolding, or adding a new Dapr University learning track/course (or a new challenge) for Instruqt in this repo — covers the track folder layout, the README.md config format, assignment.md authoring with Instruqt annotations, setup scripts, secrets handling, check/solve validation, and Robot Framework drift tests.
---

# Creating University Tracks

## Overview

A **track** is a self-paced, browser-based Dapr course hosted on [Instruqt](https://instruqt.com/) and launched from [Dapr University](https://www.diagrid.io/university). A track is a top-level folder in this repo containing an ordered set of **challenges** (one numbered subfolder each). This repo is the source of truth; Instruqt syncs the Markdown and scripts.

**Critical:** In this repo, Instruqt track and challenge **configuration lives in `README.md` files** — NOT in `track.yml` / `config.yml`. Do not create `track.yml`, `config.yml`, or extensionless lifecycle files (`setup`/`check`/`solve`). Follow the layout below exactly.

## Sizing constraints (default)

- **4–5 challenges** per track.
- **~5 minutes** per challenge.
- **Total < 30 minutes.** Set `## Time limit (minutes)` to ~30 and offer `### Extra time` of 5–10.
- The first challenge is often a light intro (read + verify environment); the last can be a light recap. Keep hands-on challenges focused on one concept each.

If the topic needs more, ask the user before exceeding 5 challenges or 30 minutes.

## Directory structure

```
<track-slug>/
  README.md                    # TRACK config (Name, Url, Teaser, Time limit, Description, timeouts)
  website-description.md        # Optional: marketing copy for the Dapr University website
  _setup/
    sandbox-setup.sh            # Runs at EVERY sandbox launch (clone code, docker login, dapr init, agent variable set)
    image-<slug>-install.sh     # OR vm-setup.sh / Dockerfile — builds the base VM image once (installs SDKs/CLIs)
  1-<challenge-slug>/
    README.md                   # CHALLENGE config (Name, Url, Description)
    notes.md                    # Boot/intro text shown next to the Start button
    assignment.md               # Learner-facing instructions (the actual challenge)
    tabs.md                     # Optional: tab layout (terminal / code editor / webapp)
    scripts/
      setup.sh                  # Optional: per-challenge setup (install/configure what the VM image can't bake in, e.g. `uv`)
      check.sh                  # Optional: validation run when the learner clicks "Check"; uses fail-message
      solve.sh                  # Optional: auto-solve steps for Instruqt's "Solve" button
    tests/
      challenge.robot           # Optional: Robot Framework drift test (CI). See reference.md → Drift testing
    images/                     # Optional diagrams (referenced via raw.githubusercontent URLs)
  2-<challenge-slug>/  …  5-<challenge-slug>/
```

Number challenge folders `1-`, `2-`, … to fix ordering. Use kebab-case slugs.

## Workflow to scaffold a new track

1. **Clarify scope** with the user if not given: track title, slug, target language(s), the concept each of the 4–5 challenges teaches, and where the learner's source code comes from (see Source-code models below). Use the `superpowers:brainstorming` skill if the outline is open-ended.
2. **Study a close reference track first.** `dapr-101` (CLI + APIs, code cloned from `dapr/quickstarts`), `dapr-workflow` (multi-language, `<details>` tabs), `dapr-workflow-aspire` (single-language, build-it-live, Aspire tabs), `ai-agents-maf` (AI track needing an OpenAI key — reference for secrets handling). Match the closest one.
3. **Create the track `README.md`** (template below).
4. **Create `_setup/`** scripts for the sandbox and image (see reference.md).
5. **Create each challenge folder** with `README.md`, `notes.md`, `assignment.md`. Add `scripts/check.sh` (+ `scripts/solve.sh`) when the challenge has a verifiable end state, and `tabs.md` when the track needs a code editor or webapp tab. If the track needs a secret (see **Secrets** below — all AI-based and Catalyst-based tracks do), have the learner configure it in the **first** challenge.
6. **Add drift tests** for every runnable challenge: a `tests/challenge.robot` suite wired into `tools/track-tester/` plus a `.github/workflows/test-<track>.yml` entry. See reference.md → **Drift testing**. Without this, the track silently drops out of the CI safety net.
7. **Verify** durations sum to < 30 min (unless the user approved more), every runnable command has `,run`, every expected-output block has `,nocopy`, each `check.sh` has a matching `solve.sh`, and each runnable command is covered by the robot suite (doc-sync).

See **reference.md** in this skill folder for full file templates, the complete Instruqt annotation catalog, source-code models, and the image-build CI pattern. Load it when writing the files.

## Track README.md template

```markdown
# Name

<Descriptive track title>

## Url

<track-slug>

## Teaser

<One- or two-sentence hook describing what the learner builds/learns.>

Languages: <.NET/Python/Java>. Duration: <N> min.

## Time limit (minutes)

30

## Description

In this self-paced track, you'll learn:
- <bullet>
- <bullet>

You'll probably need around 25 minutes to complete the <N> challenges.

If your session is idle for more than 10 minutes the session will stop and you'll need to restart the track. Tracks can be started up to 5 times and you can skip challenges to continue with the challenges you didn't finish previously.

### Time out idle users (minutes)

10

### Extra time (minutes)

10
```

## Challenge README.md template

```markdown
# Name

<Challenge title>

## Url

<track-slug>-<challenge-slug>

### Description

<One sentence describing what the learner does in this challenge.>
```

## Instruqt markdown quick reference

Use these inside `assignment.md`. **Most learner mistakes come from missing these annotations.**

| Annotation | Use on | Effect |
|---|---|---|
| `` ```bash,run `` | A command the learner should execute | Renders a **Run** button (runs in the active tab) |
| `` ```shell,run,copy `` | Command + want a copy button too | Run **and** Copy buttons |
| `` ```curl,run `` | A curl call | Run button (curl tab) |
| `` ```text,nocopy `` | Expected output / logs | Plain block, **no** copy button |
| `` ```json,nocopy `` / `` ```json,copy `` | Expected JSON / JSON to paste | nocopy = display only; copy = pasteable |

- **Instruqt variables:** `[[ Instruqt-Var key="DAPR_CLI_VERSION" hostname="<host>" ]]` — set the value in `_setup/sandbox-setup.sh` with `agent variable set DAPR_CLI_VERSION 1.17.0`.
- **Callouts** (GitHub-flavored): `> [!NOTE]` and `> [!IMPORTANT]`. Use `[!IMPORTANT]` to tell the learner to click **Check**.
- **Multi-language content:** wrap per-language steps in collapsible blocks:
  ```markdown
  <details>
     <summary><b>.NET workflow code</b></summary>
  ...language-specific instructions...
  </details>
  ```
- **Images:** reference via raw GitHub URL, e.g. `![Alt](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/<track>/<challenge>/images/<file>.png?raw=true)`.
- **Structure of an assignment.md:** short intro paragraph (mention "This challenge takes about 5 minutes"), then numbered `## 1. Step`, `## 2. Step` headings, then a `---` and a one-line transition to the next challenge.

## Validation: two separate mechanisms

These are **not** alternatives — they serve different audiences. A challenge can have both, one, or neither.

### 1. Instruqt Check / Solve buttons (learner-facing, optional)

`scripts/check.sh` runs when the learner clicks **Check**. Call `fail-message "<hint>"` on failure; a zero exit means pass (echoing a success message is optional):

```bash
if [ -n "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    echo "Dapr is running! 👍"
else
    fail-message "Dapr containers not running. Did you run 'dapr init'?"
fi
```

`scripts/solve.sh` contains the exact commands that complete the challenge, backing Instruqt's **Solve** button. Add this pair only to challenges with a verifiable end state; pure-reading challenges need neither. Not every track uses them — `dapr-workflow` has neither and relies solely on drift tests.

### 2. Robot Framework drift tests (CI-facing, expected for runnable tracks)

`solve.sh` is **not** how the track is tested end-to-end. That job belongs to the Robot Framework harness in `tools/track-tester/`: a `tests/challenge.robot` suite runs the *actual* `,run` commands from each `assignment.md` and asserts on their output, catching drift against upstream code. This is the dominant pattern in newer tracks (`dapr-workflow`, `dapr-workflow-aspire`, `dapr-101`). See reference.md → **Drift testing** for the full pattern, doc-sync, and the CI workflow.

## Secrets (AI / Catalyst tracks)

Any track that calls an LLM or Catalyst needs a secret (e.g. an OpenAI API key). **The learner supplies it themselves in the first challenge** — never bake a key into the image or scripts. Two accepted patterns:

- **`.env` file** — the learner copies an example (`cp .env.example .env`) and pastes their key.
- **Shell environment variable** — the learner `export`s the key in the terminal tab.

Announce the requirement in the track `README.md` teaser ("Requires an OpenAI API key.") and validate it with `scripts/check.sh` (e.g. grep the `.env` for a non-empty value). Keep the real secret file git-ignored.

## Source-code models

Pick one (see reference.md for full detail):
- **Clone an external repo** (e.g. `dapr/quickstarts`) in `_setup/sandbox-setup.sh`; assignments `cd` into example folders. Used by `dapr-101` and `dapr-workflow`. Best when the code already exists upstream.
- **Build it live**: the learner scaffolds and writes the app during the challenges (paste code from `,copy` blocks). Used by `dapr-workflow-aspire`. Best for "build from scratch" narratives.

Source code "typically lives in another repo" — prefer cloning an existing quickstart/examples repo over committing app code into this tracks repo.

## Common mistakes

| Mistake | Fix |
|---|---|
| Creating `track.yml` / `config.yml` | This repo uses `README.md` for config. Never create those. |
| Extensionless `setup`/`check`/`solve` at challenge root | Use `assignment.md`, `notes.md`, and `scripts/setup.sh` / `scripts/check.sh` / `scripts/solve.sh`. |
| Shipping a runnable track with no `tests/challenge.robot` | Add a drift-test suite + CI workflow entry, or the track drops out of the safety net. |
| Baking a secret/API key into the image or scripts | The learner sets it in challenge 1 via a `.env` file or a shell env var; validate with `check.sh`. |
| Omitting `### Time out idle users` / `### Extra time` from the track README | Both sections are required in every track `README.md`. |
| Forgetting `notes.md` | Every challenge needs the boot/intro text shown by the Start button. Challenge 1 uses the full intro; challenges 2+ use the "sandbox for this challenge is being prepared…" opener (see reference.md). |
| Plain `` ```bash `` for a command | Add `,run` so the learner gets a Run button. |
| Copy button on expected output | Use `,nocopy` on output/log/JSON-display blocks. |
| Over-scoping | Keep to 4–5 challenges, ~5 min each, < 30 min total. Ask before exceeding. |
| No transition / `---` at the end of `assignment.md` | End each assignment with `---` and a one-line lead-in to the next challenge. |
| `check.sh` exits non-zero with no hint | Always use `fail-message "<actionable hint>"`. |
| Committing app source into this repo | Prefer cloning an external quickstarts/examples repo in `sandbox-setup.sh`. |

## Checklist

- [ ] Track `README.md` with Name, Url, Teaser (+ Languages/Duration line), Time limit, Description, `### Time out idle users`, `### Extra time`
- [ ] 4–5 numbered challenge folders, total < 30 min
- [ ] Each challenge: `README.md` + `notes.md` + `assignment.md`
- [ ] Challenge 1 `notes.md` uses the full intro; challenges 2+ use the "sandbox for this challenge is being prepared…" opener
- [ ] `tabs.md` where a code editor or webapp tab is needed
- [ ] `scripts/check.sh` (+ `fail-message`) and `scripts/solve.sh` for verifiable challenges; `scripts/setup.sh` for per-challenge install/config
- [ ] Secret (AI/Catalyst tracks) set by the learner in challenge 1 via `.env` or shell env var — never baked in
- [ ] `tests/challenge.robot` drift suite + `.github/workflows/test-<track>.yml` for every runnable challenge
- [ ] `_setup/sandbox-setup.sh` (+ image install script) covering tools, code, and `agent variable set`
- [ ] Every runnable command tagged `,run`; every output block tagged `,nocopy`; every `,run` command covered by the robot suite (doc-sync)
- [ ] Each `assignment.md` ends with `---` + transition
- [ ] Source code cloned from an external repo (not committed here) unless building live
