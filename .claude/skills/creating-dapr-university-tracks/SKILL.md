---
name: creating-university-tracks
description: Use when creating, scaffolding, or adding a new Dapr University learning track/course (or a new challenge) for Instruqt in this repo — covers the track folder layout, the README.md config format, notes.md and assignment.md authoring with Instruqt annotations, tabs.md and terminal naming, how the final challenge closes, setup scripts, secrets handling, check/solve validation, and Robot Framework drift tests.
---

# Creating University Tracks

## Overview

A **track** is a self-paced, browser-based Dapr course hosted on [Instruqt](https://instruqt.com/) and launched from [Dapr University](https://www.diagrid.io/university). A track is a top-level folder in this repo containing an ordered set of **challenges** (one numbered subfolder each). This repo is the source of truth; Instruqt syncs the Markdown and scripts.

**Critical:** In this repo, Instruqt track and challenge **configuration lives in `README.md` files** — NOT in `track.yml` / `config.yml`. Do not create `track.yml`, `config.yml`, or extensionless lifecycle files (`setup`/`check`/`solve`). Follow the layout below exactly.

## Sizing constraints (default)

- **3–5 challenges** per track.
- **~5 minutes** per challenge.
- **Total < 30 minutes.** Set `## Time limit (minutes)` to ~30 and offer `### Extra time` of 5–10.
- The first challenge is often a light intro (read + verify environment); the last can be a light recap. Keep hands-on challenges focused on one concept each.

If the topic needs more, ask the user before exceeding 5 challenges or 30 minutes.

**Which tracks are sizing models:** `dapr-secrets` (4 challenges / 30 min) and `dapr-workflow-aspire` (5 / 30) are on-spec. `dapr-101` (5 / 45) and `dapr-workflow` (11 / 50) predate the rule — copy their conventions, never their size.

## Directory structure

```
<track-slug>/
  README.md                    # REQUIRED. Track config (Name, Url, Teaser, Time limit, Description, both timeouts)
  website-description.md        # Optional: marketing copy for the Dapr University website (prose or structured)
  _setup/
    sandbox-setup.sh            # REQUIRED. Runs at EVERY sandbox launch, so make it safe to run twice
    image-<slug>-install.sh     # Optional: builds the base VM image once (installs SDKs/CLIs). Also seen as vm-setup.sh
  1-<challenge-slug>/
    README.md                   # REQUIRED for new tracks. Challenge config (Name, Url, Description)
    notes.md                    # REQUIRED. Boot/intro text shown next to the Start button
    assignment.md               # REQUIRED. Learner-facing instructions (the actual challenge)
    tabs.md                     # Optional, but expected for new tracks: tab layout (terminal / code editor / webapp)
    scripts/
      setup.sh                  # Optional: per-challenge setup. Must be SELF-SUFFICIENT — a learner can jump straight here via *Progress*
      check.sh                  # Optional: validation run when the learner clicks "Check"; uses fail-message
      solve.sh                  # Optional: auto-solve steps for Instruqt's "Solve" button
    tests/
      challenge.robot           # Optional: Robot Framework drift test (CI). See reference.md → Drift testing
    images/                     # Optional diagrams, referenced by raw-GitHub URL. Only dapr-workflow has one
  2-<challenge-slug>/  …  5-<challenge-slug>/
```

Number challenge folders `1-`, `2-`, … to fix ordering. Use kebab-case slugs.

## Workflow to scaffold a new track

1. **Clarify scope** with the user if not given: track title, slug, target language(s), the concept each of the 4–5 challenges teaches, and where the learner's source code comes from (see Source-code models below). Use the `superpowers:brainstorming` skill if the outline is open-ended.
2. **Study a close reference track first.** Default to **`dapr-secrets`** — newest, on-spec (4 challenges / 30 min), and the only track carrying the complete file set in every challenge. Use `dapr-workflow-aspire` for a build-it-live track, `dapr-101` when you need four languages from `dapr/quickstarts`, and `ai-agents-maf` only as the reference for a learner-supplied API key. `dapr-workflow` is legacy — borrow its `<details>` and diagram conventions, never its sizing. Copy the closest challenge folder and adapt it.
3. **Create the track `README.md`** (template below).
4. **Create `_setup/`** scripts for the sandbox and image (see reference.md).
5. **Create each challenge folder** with `README.md`, `notes.md`, `assignment.md`. Add `scripts/check.sh` (+ `scripts/solve.sh`) when the challenge has a verifiable end state, and `tabs.md` when the track needs a code editor or webapp tab. If the track needs a secret (see **Secrets** below — all AI-based and Catalyst-based tracks do), have the learner configure it in the **first** challenge.
6. **Add drift tests** for every runnable challenge: a `tests/challenge.robot` suite wired into `tools/track-tester/` plus a `.github/workflows/test-<track>.yml` entry. See reference.md → **Drift testing**. Without this, the track silently drops out of the CI safety net.
7. **Verify** durations sum to < 30 min (unless the user approved more), every runnable command has `,run`, every expected-output block has `,nocopy`, each `check.sh` has a matching `solve.sh`, and each runnable command is covered by the robot suite (doc-sync).

See **reference.md** in this skill folder for the `notes.md` and `assignment.md` anatomy, the closing section of the final challenge, `tabs.md`, images, setup- and per-challenge-script patterns, source-code models, and drift testing. Load it when writing the files.

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

`### Time out idle users (minutes)` and `### Extra time (minutes)` are **required** for new tracks. `dapr-workflow-aspire/README.md` omits both and also uses `## Name` / `## URL` where every other track uses `# Name` / `## Url` — it is the outlier, not the model.

## Challenge README.md template

```markdown
# Name

<Challenge title>

## Url

<track-slug>-<challenge-slug>

### Description

<One sentence describing what the learner does in this challenge.>
```

Note the heading levels: `# Name` is an H1, `## Url` an H2, `### Description` an H3. The `Url` is `<track-slug>-<challenge-slug>` — consistent across all four `dapr-secrets` challenges, inconsistent in `dapr-101` (`dapr-intro-challenge-1`, `dapr-101-cli`, `dapr-101-pub-sub`), which is the older style. `dapr-workflow` and `dapr-workflow-aspire` have **no** challenge `README.md` files at all; their challenge config lives in the Instruqt UI, which is what this repo exists to replace. New tracks write one per challenge.

## Instruqt markdown quick reference

Use these inside `assignment.md`. **Most learner mistakes come from missing these annotations.**

Ask one question: does the learner **execute** it, **paste** it, or only **read** it?

| Annotation | Use on | Effect |
|---|---|---|
| `` ```bash,run `` | A command the learner executes — the default, and by far the most common | Renders a **Run** button |
| `` ```bash,run,copy `` / `` ```shell,run,copy `` | Same, when the learner may also want to paste it somewhere else. Prefer `bash` — only `bash` fences are doc-sync-checked | Run **and** Copy buttons |
| `` ```curl,run `` | A curl call. `dapr-workflow` uses it; `dapr-secrets` writes curl as `bash,run` | Run button. Either is accepted — be consistent within a track |
| `` ```text,nocopy `` / `` ```json,nocopy `` | Expected output, logs, returned JSON | Plain block, **no** copy button |
| `` ```<lang>,copy `` | Code or config the learner pastes into a file (build-it-live tracks) | Copy button |
| `` ```<lang>,copy,wrap `` | Same, for long lines | Copy button + soft wrap |
| `` ```yaml `` (bare, no flags) | An illustrative fragment the learner only reads, never runs or pastes | No button at all |

- **Instruqt variables:** `[[ Instruqt-Var key="DAPR_CLI_VERSION" hostname="<host>" ]]` — set the value in `_setup/sandbox-setup.sh` with `agent variable set DAPR_CLI_VERSION 1.18.0`. Keep those lines in plain `agent variable set NAME VALUE` form; CI parses versions back out of them.
- **Callouts** (GitHub-flavored): `> [!NOTE]` and `> [!IMPORTANT]`. Use `[!IMPORTANT]` for the Run-button/terminal callout, a precondition the learner must not skip, and "click *Check* before continuing"; `[!NOTE]` for the "expand the language-specific instructions" lead-in and asides.
- **Multi-language content:** wrap per-language steps in collapsible blocks:
  ```markdown
  <details>
     <summary><b>.NET workflow code</b></summary>
  ...language-specific instructions...
  </details>
  ```
- **Images:** reference via raw GitHub URL, e.g. `![Alt](https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/<track>/<challenge>/images/<file>.png?raw=true)`.
- **Structure of an assignment.md:** **no H1** (Instruqt renders the title from the challenge `README.md`), then a plain intro paragraph ending `This hands-on challenge takes about N minutes to complete.` (`theoretical` when the challenge has no `,run` commands), then numbered `## 1. Step`, `## 2. Step` headings, then `---` and a one-line transition to the next challenge. The **last** challenge ends with a closing section instead of a transition — see reference.md → **Closing the final challenge**. Full anatomy: reference.md → **assignment.md anatomy**.

## Validation: two separate mechanisms

These are **not** alternatives — they serve different audiences. A challenge can have both, one, or neither.

### 1. Instruqt Check / Solve buttons (learner-facing, optional)

`scripts/check.sh` runs when the learner clicks **Check**. Write one branch per distinguishable failure, most-specific first, each calling `fail-message "<hint>"` and `exit 1` — the hint should name the action that fixes it, not just the symptom. (Instruqt treats a zero exit as a pass, but relying on that alone makes a multi-branch check easy to get wrong.)

```bash
if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "Dapr containers not running. Did you run 'dapr init'?"
    exit 1
elif [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:5001/secret/orderdb-password)" != "200" ]; then
    fail-message "The app doesn't answer on port 5001. Is 'dapr run -f .' running in the demo folder?"
    exit 1
else
    echo "The app reads its secret! 👍"
fi
```

`scripts/solve.sh` contains the exact commands that complete the challenge, backing Instruqt's **Solve** button. Add this pair only to challenges with a verifiable end state; pure-reading challenges need neither. Not every track uses them — `dapr-workflow` has neither and relies solely on drift tests.

### 2. Robot Framework drift tests (CI-facing, expected for runnable tracks)

`solve.sh` is **not** how the track is tested end-to-end. That job belongs to the Robot Framework harness in `tools/track-tester/`: a `tests/challenge.robot` suite runs the *actual* `,run` commands from each `assignment.md` and asserts on their output, catching drift against upstream code. All four runnable tracks have suites (`dapr-101`, `dapr-workflow`, `dapr-workflow-aspire`, `dapr-secrets`), and each has a CI workflow on a daily cron. Only fences starting with `bash` and carrying `run` are doc-sync-checked (`shell,run` and `curl,run` are not — cover them anyway, nothing will warn you); commands the suite performs indirectly are declared in a trailing `# doc-sync coverage (<why>):` comment block. See reference.md → **Drift testing** for the full pattern, the suite conventions, and the CI workflow.

## Secrets (AI / Catalyst tracks)

Any track that calls an LLM or Catalyst needs a secret (e.g. an OpenAI API key). **The learner supplies it themselves in the first challenge** — never bake a key into the image or scripts. Two accepted patterns:

- **`.env` file** — the learner copies an example (`cp .env.example .env`) and pastes their key.
- **Shell environment variable** — the learner `export`s the key in the terminal tab.

Announce the requirement in the track `README.md` teaser ("Requires an OpenAI API key.") and validate it with `scripts/check.sh` (e.g. grep the `.env` for a non-empty value). Keep the real secret file git-ignored.

## Source-code models

Pick one (see reference.md for full detail):
- **Clone an external repo** in `_setup/sandbox-setup.sh`; assignments `cd` into example folders. Two upstreams are in use: `dapr/quickstarts` (not ours to change — `dapr-101`, `dapr-workflow`) and `diagrid-labs/ai-agent-tracks-instruqt`, this org's own demo-app repo (`dapr-secrets`, `ai-agents-maf`). When the demo app doesn't exist upstream yet, add it to `ai-agent-tracks-instruqt` — not to this repo.
- **Build it live**: the learner scaffolds and writes the app during the challenges (paste code from `,copy` blocks). Used by `dapr-workflow-aspire`. Best for "build from scratch" narratives.

Source code "typically lives in another repo" — prefer cloning an existing quickstart/examples repo over committing app code into this tracks repo.

## Common mistakes

Things that go wrong by default. (What must *exist* is the Checklist; what must be *proven to work* is reference.md → **Final pre-flight checks**.)

| Mistake | Fix |
|---|---|
| Creating `track.yml` / `config.yml` | This repo uses `README.md` for config. Never create those. |
| Extensionless `setup`/`check`/`solve` at challenge root | Use `assignment.md`, `notes.md`, and `scripts/setup.sh` / `scripts/check.sh` / `scripts/solve.sh`. |
| An `# H1` title at the top of `assignment.md` | There is none. Instruqt renders the title from the challenge `README.md`'s `# Name`. |
| Plain `` ```bash `` for a command | Add `,run` so the learner gets a Run button — and cover that command in the robot suite. |
| Copy button on expected output | Use `,nocopy` on output/log/JSON-display blocks; a bare fence for a fragment that's only read. |
| Multi-terminal track with no Run-button callout | Open every `assignment.md` with the `> [!IMPORTANT]` "select the matching terminal" block — see reference.md → **tabs.md**. |
| `---` after the opener in a challenge-2+ `notes.md` | Only challenge 1's `notes.md` has a `---`. Later ones are opener + one summary line + docs link. |
| Challenge 1 `notes.md` with no introduction after the `---` | It carries either conceptual prose or an "In this first challenge, you'll:" list — plus the challenge count, restart and docs/Discord lines. |
| Last challenge ends with a plain transition | The final `assignment.md` closes with a recap, the feedback/badge H2, and the three *Next steps* sub-headings. See reference.md → **Closing the final challenge**. |
| Inventing a Holopin badge link for a new track | Badges are created outside this repo. Omit the badge block until one exists. |
| A `sandbox-setup.sh` that breaks on a relaunch | It runs at every sandbox launch. Guard the clone, `dapr init` and tool installs so running it twice is safe. |
| A `scripts/setup.sh` that assumes an earlier challenge ran | Learners jump between challenges with *Progress*. Each challenge's setup must stand alone. |
| `check.sh` exits non-zero with no hint | One branch per distinguishable failure, each with `fail-message "<actionable hint>"` and `exit 1`. |
| Shipping a runnable track with no `tests/challenge.robot` | Add a drift-test suite + CI workflow entry, or the track drops out of the safety net. |
| A single-line `# doc-sync coverage: <cmd>` comment | Use the trailing block: `# doc-sync coverage (<why>):` then one indented line per command. |
| Omitting `### Time out idle users` / `### Extra time` from the track README | Both are required for new tracks. `dapr-workflow-aspire` omits them — it is the outlier. |
| Copying `dapr-101` or `dapr-workflow` sizing | They are 45 and 50 minutes. Keep to 4–5 challenges, ~5 min each, < 30 min. Ask before exceeding. |
| Baking a secret/API key into the image or scripts | The learner sets it in challenge 1 via a `.env` file or a shell env var; validate with `check.sh`. |
| Committing app source into this repo | Clone it from `dapr/quickstarts` or `diagrid-labs/ai-agent-tracks-instruqt` in `sandbox-setup.sh`. |

## Checklist

What must exist before the track is done. Every line is checkable against `dapr-secrets`.

- [ ] Track `README.md`: `# Name`, `## Url`, `## Teaser` (+ Languages/Duration line), `## Time limit (minutes)`, `## Description`, `### Time out idle users (minutes)`, `### Extra time (minutes)`
- [ ] 4–5 numbered challenge folders, total < 30 min
- [ ] Each challenge: `README.md` (`# Name` / `## Url` = `<track-slug>-<challenge-slug>` / `### Description`) + `notes.md` + `assignment.md`
- [ ] Challenge 1 `notes.md`: full intro, docs + Discord paragraph, `---`, then the topic introduction. Challenges 2+: opener, summary line, docs link, **no `---`**
- [ ] Each `assignment.md`: no H1; intro ending "This hands-on/theoretical challenge takes about N minutes to complete."; numbered `## N.` steps; `---` + transition
- [ ] The **last** `assignment.md` closes with the recap + feedback/badge section + the three *Next steps* sub-headings
- [ ] `tabs.md` per challenge, terminals named after what runs in them; the Run-button callout in every assignment if there's more than one terminal
- [ ] `scripts/setup.sh` (self-sufficient) where the challenge needs prep; `scripts/check.sh` + `scripts/solve.sh` where there's a verifiable end state
- [ ] Secret (AI/Catalyst tracks) set by the learner in challenge 1 via `.env` or shell env var — never baked in
- [ ] `_setup/sandbox-setup.sh`, safe to run twice, with every `Instruqt-Var` the assignments use set via `agent variable set`
- [ ] `_setup/image-<slug>-install.sh` if the track needs its own VM image — otherwise it reuses another track's host
- [ ] Every runnable command tagged `,run`; every output block `,nocopy`; every `,run` command covered by the suite, indirect ones in the `# doc-sync coverage (<why>):` block
- [ ] `tests/challenge.robot` per runnable challenge (or one track-level suite for build-it-live)
- [ ] `tools/track-tester/variables/<track_with_underscores>.py` (e.g. `dapr_secrets.py`), `tools/track-tester/ci/setup-<track>.sh`, `.github/workflows/test-<track>.yml` on a free cron slot, and a row in the repo `README.md` workflow table
- [ ] Source code cloned from an external repo (not committed here) unless building live
- [ ] `website-description.md` if the track goes on the Dapr University site
