# Legacy Instruqt 1.0 tracks

Only for editing the legacy tracks: dapr-workflow, dapr-workflow-aspire, dapr-dotnet-aspire, dapr-agents, dapr-agents-web-context, ai-agents-deepagents, ai-agents-maf, catalyst-101. New tracks are 2.0 labs: see SKILL.md.

The assignment annotations (SKILL.md → Assignment quick reference) and the drift-test conventions
(reference.md → Drift tests and CI) apply to 1.0 tracks too. Everything else that differs is below.

**Critical:** in this repo, 1.0 track and challenge **configuration lives in `README.md` files**, not
in `track.yml` / `config.yml`. Do not create `track.yml`, `config.yml`, or extensionless lifecycle
files (`setup`/`check`/`solve`).

## Migrating a 1.0 track to 2.0

When you migrate `ai-agents-maf`, `ai-agents-deepagents` or `ai-agents-supply-chain-auditor-langchain`
to a 2.0 lab:

- Use the `diagrid/dapr-sandbox` module's clone of `diagrid-labs/university-labs` (formerly
  `ai-agent-tracks-instruqt`) and its folder; don't add a clone to a setup script.
- Move every `ai-agent-tracks-instruqt/...` path to `/root/university-labs/...`.
- Delete the 1.0 folder once the 2.0 lab replaces it.

## Reference tracks

| Track | Languages | Source-code model | Notable conventions | Use it when |
|---|---|---|---|---|
| `dapr-workflow` | .NET/Java/Python | Clones `dapr/quickstarts` | 11 challenges / **50 min, do not imitate the size**. Heavy `<details>` per-language blocks, per-challenge `images/` folders, per-challenge `tests/challenge.robot` (no check/solve) | You need the `<details>` or diagram conventions. |
| `dapr-workflow-aspire` | .NET only | Build-it-live (learner scaffolds) | 5 challenges / 30 min. `tabs.md` with Editor/Terminal/Aspire webapp tabs, custom VM image, `,copy` code blocks, a single track-level `tests/challenge.robot` that rebuilds the app from the assignments, Instruqt-hosted images. **The README outlier**: `## Name`/`## URL` and no timeout sections | The narrative is "build it from scratch" and there is no upstream repo. |
| `ai-agents-maf` | .NET only | Clones `diagrid-labs/university-labs` (formerly `ai-agent-tracks-instruqt`) | Requires an OpenAI key (set by learner in ch1, validated by `check.sh`), `scripts/setup.sh`, Editor+Terminal tabs. No drift tests | A track that needs a learner-supplied API key. |

## Sizing

Same limits as a 2.0 lab: 3 to 5 challenges, about 5 minutes each, total under 30 minutes. In a 1.0
track they live in the track `README.md`: `## Time limit (minutes)` of about 30 and
`### Extra time (minutes)` of 5 to 10. `dapr-workflow` (50) predates the rule.

## Directory structure

```
<track-slug>/
  README.md                    # REQUIRED. Track config (Name, Url, Teaser, Time limit, Description, both timeouts)
  website-description.md       # Optional: marketing copy for the Dapr University website
  _setup/
    sandbox-setup.sh           # REQUIRED. Runs at EVERY sandbox launch, so make it safe to run twice
    image-<slug>-install.sh    # Optional: builds the base VM image once (installs SDKs/CLIs). Also seen as vm-setup.sh
  1-<challenge-slug>/
    README.md                  # Challenge config (Name, Url, Description)
    notes.md                   # REQUIRED. Boot/intro text shown next to the Start button
    assignment.md              # REQUIRED. Learner-facing instructions
    tabs.md                    # Optional: tab layout (terminal / code editor / webapp)
    scripts/
      setup.sh                 # Optional: per-challenge setup. Must be SELF-SUFFICIENT
      check.sh                 # Optional: validation run when the learner clicks "Check"; uses fail-message
      solve.sh                 # Optional: auto-solve steps for Instruqt's "Solve" button
    tests/
      challenge.robot          # Drift test (CI)
    images/                    # Optional diagrams, referenced by raw-GitHub URL
```

Number challenge folders `1-`, `2-`, … to fix ordering. Use kebab-case slugs.

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

`### Time out idle users (minutes)` and `### Extra time (minutes)` are required. `dapr-workflow-aspire/README.md`
omits both and uses `## Name` / `## URL`: it is the outlier, not the model.

## Challenge README.md template

```markdown
# Name

<Challenge title>

## Url

<track-slug>-<challenge-slug>

### Description

<One sentence describing what the learner does in this challenge.>
```

`# Name` is an H1, `## Url` an H2, `### Description` an H3. `dapr-workflow` and `dapr-workflow-aspire`
have no challenge `README.md` files; their challenge config lives in the Instruqt UI.

## notes.md templates

Shown beside the **Start** button while the sandbox boots. Model: `dapr-workflow/1-durable-execution/notes.md`.

### Challenge 1 (full intro)

1. The Start-button sentence.
2. A bullet list: how many challenges and what the idle timeout does; that tracks can be started up
   to 5 times and challenges picked via the *Progress* button.
3. Only if the track has a badge: a bullet saying so, and the badge image.
4. A paragraph linking the relevant Dapr Docs page, then the *#university* channel of the
   [Dapr Discord](https://diagrid.ws/dapr-discord).
5. `---`
6. The introduction to the topic: conceptual prose, or a short "In this first challenge, you'll:"
   bullet list.

~~~markdown
Click the *Start* button to setup the sandbox environment for this training, this may take up to 2 minutes. Once the environment is ready, click the *Start* button again.

- There are <N> challenges to complete. If your session is idle for more than 10 minutes, the session will stop, and you'll need to restart the track.

- Tracks can be started up to 5 times, and you can select which challenge you want to run via the *Progress* button in the top right, if you don't want to run them all in order.

If you need more information about <topic> during (or after) the challenge, visit the [Dapr Docs](<url>). If you have any questions or feedback about this track, you can let us know in the *#university* channel of the [Dapr Discord server](https://diagrid.ws/dapr-discord).

---

In this challenge, you'll <what they will learn>.
~~~

### Challenges 2 and onwards

Short, and **no `---`**.

~~~markdown
The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the *Start* button.

In this challenge you'll <one- or two-sentence summary>.

If you need more information about <topic> during (or after) the challenge, visit the [<page name>](<docs url>).
~~~

## assignment.md in a 1.0 track

1. **No H1 title.** Instruqt renders the title from the challenge `README.md`'s `# Name`.
2. **Opening paragraph** ending `This hands-on challenge takes about N minutes to complete.`
   (`theoretical` when the challenge has no `,run` commands).
3. **A `> [!IMPORTANT]` callout** for the Run-button/terminal note on a multi-terminal track, a
   precondition, or "click *Check* before continuing".
4. **Numbered `## N. Title` steps**, each with its commands and expected output.
5. **`---` and a one-line transition** to the next challenge, except on the last challenge.

Model: `dapr-workflow/3-task-chaining/assignment.md`.

### Instruqt variables

`[[ Instruqt-Var key="DAPR_CLI_VERSION" hostname="<host>" ]]` shows a value set in
`_setup/sandbox-setup.sh` with `agent variable set DAPR_CLI_VERSION <version>`. Keep those lines in
plain `agent variable set NAME VALUE` form; CI parses versions back out of them.

### Closing the final challenge

After `---`: a recap (a paragraph plus one bold-titled line per challenge, or a `## Summary`
paragraph); `## Collect your badge & provide feedback` (badge tracks)
or `## Feedback and further learning`; a congratulations sentence containing *"rate this training
and provide feedback in the next step"*; the badge link and image where one exists; then
`**Try another university track**`, `**Read more**`, `**Join the community**` (under `## Next steps`
on badge tracks). Copy the current wording from the newest 1.0 track.

## tabs.md

Defines the IDE tabs. Omit it for a single-terminal track. Each tab is a `## <Tab name>` section:

```markdown
# Tab configuration

## Editor

type: code editor
host: dotnet-10-aspire
path: dapr-workflow-aspire/EnterpriseDiagnostics

## Terminal

type: terminal
host: dotnet-10-aspire
path: dapr-workflow-aspire/EnterpriseDiagnostics

## Aspire

type: service/webapp
host: dotnet-10-aspire
path: (empty)
port: 17000
protocol: http
```

`host` must match the hostname used elsewhere (sandbox host, Instruqt-Var `hostname=`). Name
terminals after what runs in them, and on a multi-terminal track put the Run-button callout in every
`assignment.md`.

## Images

Prefer a per-challenge `images/` folder with a raw-GitHub URL (as `dapr-workflow` does). `dapr-workflow-aspire`
uses Instruqt-hosted assets, which are not in the repo. Avoid the last one.

## _setup/sandbox-setup.sh

Runs at **every** sandbox launch, including a relaunch. **Write it so running it twice is safe.** It
clones source code, installs and initialises Dapr, sets Instruqt variables and pre-builds anything
slow.

```bash
set -euo pipefail

[ -d "$HOME/quickstarts/.git" ] || git clone https://github.com/dapr/quickstarts.git "$HOME/quickstarts"

agent variable set DAPR_CLI_VERSION <pinned-cli-version>
agent variable set DAPR_RUNTIME_VERSION <pinned-runtime-version>
```

Guards worth copying: `set -euo pipefail`; clone only when the target has no `.git`; `dapr init`
only when the placement, scheduler and redis containers are not running (with a `dapr uninstall` +
`dapr init` retry); install a tool only when `command -v` fails (`uv` lands in `$HOME/.local/bin`);
re-create a dev-mode container rather than reuse it.

**Version pins live here and nowhere else**, in `agent variable set` lines that CI parses.

## Per-challenge scripts

They live in `<challenge>/scripts/`.

**`scripts/setup.sh` must be self-sufficient.** A learner can jump straight to challenge 3 from the
*Progress* button, so it may not assume `sandbox-setup.sh` or an earlier challenge ran.

**`scripts/check.sh`: one branch per distinguishable failure**, most specific first, each calling
`fail-message "<hint>"` and `exit 1`. The hint names the action that fixes it.

```bash
if [ -z "$(docker ps -f "name=dapr_redis" -f "status=running" -q)" ]; then
    fail-message "Dapr containers not running. Did you run 'dapr init'?"
    exit 1
else
    echo "Dapr is initialised! 👍"
fi
```

**`scripts/solve.sh` actually solves it**: it applies the same edit the assignment asks for, frees
the ports, restarts in the background with `nohup`, and polls until the app answers. Add the
check/solve pair only to challenges with a verifiable end state. `dapr-workflow` has neither and
relies on drift tests.

## Image install script

Builds the base VM image, run by Instruqt when the image is built (no Dockerfile anywhere in this
repo). Names in use: `image-<slug>-install.sh` (`dapr-workflow`), `image-install.sh`,
`image-definition.sh`, `vm-setup.sh`. Prefer `image-<slug>-install.sh`. Keep it in sync with what the
assignments assume is installed. A track can reuse another track's image (`catalyst-101` does); then
install the rest in `sandbox-setup.sh`.

## Source-code models

- **Clone an external repo** in `_setup/sandbox-setup.sh` (`dapr/quickstarts` for
  `dapr-workflow`; `diagrid-labs/university-labs` (formerly `ai-agent-tracks-instruqt`) for `ai-agents-maf`). `dapr/quickstarts`
  uses a `resources/` folder for components.
- **Build it live**: the learner scaffolds the app and pastes code from `,copy` blocks
  (`dapr-workflow-aspire`). Its suite pulls commands out of the assignment at runtime with
  `libraries/assignment_blocks.py`, and its CI has no doc-sync job.

## Secrets

The learner supplies a key in challenge 1 via a `.env` file or `export`. Announce it in the teaser
and validate it in `scripts/check.sh`:

```bash
if [ ! -f ".env" ]; then
    fail-message "No .env file found. Copy .env.example to .env and paste your OpenAI API key."
elif ! grep -qE '^OPENAI_API_KEY=.+' .env; then
    fail-message "OPENAI_API_KEY is empty in .env. Paste your key after the '=' sign."
fi
```

## Common mistakes (1.0)

| Mistake | Fix |
|---|---|
| Creating `track.yml` / `config.yml` | This repo uses `README.md` for config. |
| Extensionless `setup`/`check`/`solve` at challenge root | Use `scripts/setup.sh`, `scripts/check.sh`, `scripts/solve.sh`. |
| An `# H1` at the top of a 1.0 `assignment.md` | Instruqt renders the title from the challenge `README.md`. |
| `---` after the opener in a challenge-2+ `notes.md` | Only challenge 1's `notes.md` has one. |
| A `sandbox-setup.sh` that breaks on a relaunch | Guard the clone, `dapr init` and tool installs. |
| A `scripts/setup.sh` that assumes an earlier challenge ran | Each challenge's setup must stand alone. |
| `check.sh` exits non-zero with no hint | One branch per failure, each with `fail-message` and `exit 1`. |
| Omitting the timeout sections from the track README | Both are required. |

## Pre-flight checks (1.0 additions)

- `solve.sh` then `check.sh` passes for every challenge that has the pair.
- Starting the track at challenge *N* works, because each `scripts/setup.sh` stands alone.
- `sandbox-setup.sh` survives a second run.
- Every `Instruqt-Var` key in an assignment is `agent variable set` in `sandbox-setup.sh`, and every
  `hostname=` matches a real host.
- The image install script covers every tool the assignments use.
