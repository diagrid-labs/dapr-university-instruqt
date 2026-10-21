# Reference: Dapr University track files

Full templates and details for `creating-dapr-university-tracks`. Load this when actually writing track files.

## Reference tracks to copy from

**Start from `dapr-secrets`** unless the new track is build-it-live (then `dapr-workflow-aspire`) or needs four languages from `dapr/quickstarts` (then `dapr-101`). `dapr-workflow` is legacy: good for `<details>` and diagram conventions, wrong for sizing.

| Track | Languages | Source-code model | Notable conventions | Use it when |
|---|---|---|---|---|
| `dapr-secrets` **(canonical)** | .NET/Python/Java | Clones `diagrid-labs/ai-agent-tracks-instruqt` | 4 challenges / 30 min. The only track with the complete file set in every challenge: `README.md` + `notes.md` + `assignment.md` + `tabs.md` + `scripts/setup.sh` + `tests/challenge.robot`, plus `check.sh`/`solve.sh` where there's a verifiable end state. Re-runnable `sandbox-setup.sh`; named `Dapr CLI` / `curl` terminals; a Vault container seeded at sandbox start | Default. Any new multi-language track whose demo apps live in an external repo. |
| `dapr-101` | .NET/Python/Java/JS | Clones `dapr/quickstarts` in sandbox-setup | 5 challenges / **45 min — over the default budget**. Numbered steps, Instruqt-Var versions, `scripts/check.sh`+`solve.sh`, per-challenge `tests/challenge.robot`, Holopin badge image in notes. No `tabs.md` — its language tabs are configured in the Instruqt UI | The track needs all four languages straight out of `dapr/quickstarts`. |
| `dapr-workflow` | .NET/Java/Python | Clones `dapr/quickstarts` | 11 challenges / **50 min — legacy, do not imitate the size**. Heavy `<details>` per-language blocks, the only track with per-challenge `images/` folders, per-challenge `tests/challenge.robot` (no check/solve) | You need the `<details>` or diagram conventions. Never for sizing. |
| `dapr-workflow-aspire` | .NET only | Build-it-live (learner scaffolds) | 5 challenges / 30 min. `tabs.md` with Editor/Terminal/Aspire webapp tabs, custom VM image, `,copy` code blocks, a single track-level `tests/challenge.robot` that rebuilds the app from the assignments, Instruqt-hosted images. **The README outlier** — `## Name`/`## URL` and no timeout sections; don't copy its `README.md` | The narrative is "build it from scratch" and there is no upstream repo. |
| `ai-agents-maf` | .NET only | Clones `diagrid-labs/ai-agent-tracks-instruqt` | Requires an OpenAI key (set by learner in ch1, validated by `check.sh`), `scripts/setup.sh`, Editor+Terminal tabs. No drift tests | Only as the reference for a track that needs a learner-supplied API key. |

When the new track resembles one of these, copy its closest challenge folder and adapt rather than starting from scratch.

## website-description.md (optional, newer tracks)

Marketing copy rendered on the Dapr University site. Two shapes are in use and both are accepted.

**Prose** — `dapr-secrets/website-description.md`: no H1, no headings, four paragraphs — a hook, what the learner does, the turn, what they walk away knowing. Reads better on the site; prefer it for a short track.

**Structured** — `dapr-workflow-aspire/website-description.md`, sections like:

```markdown
# <Track title>

<Lead paragraph.>

## What you'll build
...

## What you'll learn
- ...

## Supported language
.NET

## Prerequisites
...
```

## notes.md templates

Shown beside the **Start** button while the sandbox boots. **The shape differs between challenge 1 and the rest**, and challenge 1 is longer than people expect: it is the only place a learner reads about the track as a whole.

### Challenge 1 (full intro)

Model: `dapr-secrets/1-what-is-the-secrets-api/notes.md`. In order:

1. The Start-button sentence — "Click the *Start* button to setup the sandbox environment for this training, this may take up to 2 minutes. Once the environment is ready, click the *Start* button again." (`dapr-101` and `dapr-secrets` both carry a typo here, "Once the environment ready" — write it correctly.)
2. A bullet list: how many challenges and what the idle timeout does; that tracks can be started up to 5 times and challenges picked via the *Progress* button. `dapr-workflow-aspire` adds a bullet about extending the time by 10 minutes.
3. **Only if the track has a badge** — a bullet saying so, and the badge image. See **Closing the final challenge**.
4. A paragraph linking the relevant Dapr Docs page, then the *#university* channel of the [Dapr Discord](https://diagrid.ws/dapr-discord).
5. `---`
6. **The introduction to the topic.** Two shapes exist and both are fine: paragraphs of conceptual prose — what the thing is and why it matters, which is what the learner reads while the sandbox boots (`dapr-secrets`, `dapr-101`) — or a short "In this first challenge, you'll:" bullet list (`dapr-workflow`, `dapr-workflow-aspire`). Prose for a concept the learner hasn't met; bullets when the challenge is mostly mechanical. Those two tracks also put the docs/Discord paragraph *after* the `---` rather than before it.

~~~markdown
Click the *Start* button to setup the sandbox environment for this training, this may take up to 2 minutes. Once the environment is ready, click the *Start* button again.

- There are <N> challenges to complete. If your session is idle for more than 10 minutes, the session will stop, and you'll need to restart the track.

- Tracks can be started up to 5 times, and you can select which challenge you want to run via the *Progress* button in the top right, if you don't want to run them all in order.

If you need more information about <topic> during (or after) the challenge, visit the [Dapr Docs](<url>). If you have any questions or feedback about this track, you can let us know in the *#university* channel of the [Dapr Discord server](https://diagrid.ws/dapr-discord).

---

In this challenge, you'll <what they will learn>.

<One to four paragraphs introducing the concept.>
~~~

### Challenges 2 and onwards

Short, and **no `---`** — no `notes.md` for challenge 2+ in any track has one.

~~~markdown
The sandbox for this challenge is being prepared, it should be ready within a few seconds. Once it's ready, click the *Start* button.

In this challenge you'll <one- or two-sentence summary of what the learner will achieve>.

If you need more information about <topic> during (or after) the challenge, visit the [<page name>](<docs url>).
~~~

Two variants worth knowing: `dapr-workflow/11-challenges-and-tips` opens with "The sandbox for the **final** challenge…", and `dapr-workflow-aspire` uses a bullet list instead of the sentence and links the *#general* Discord channel. **Use *#university*** — it is what the other three tracks use and what the channel is for.

## assignment.md anatomy

Assignments follow one shape across every track. In order:

1. **No H1 title.** Instruqt renders the title from the challenge `README.md`'s `# Name`. No `assignment.md` in this repo opens with `# `.
2. **Opening paragraph** — plain, unbolded, one to three sentences saying what the learner will do, ending with the duration: `This hands-on challenge takes about N minutes to complete.` Write `theoretical` instead of `hands-on` when the challenge has no `,run` commands (`dapr-101/1-what-is-dapr`, `dapr-workflow/1-durable-execution`, `dapr-workflow/11-challenges-and-tips`). Older assignments vary the wording ("This challenge will take about 5 minutes") and `dapr-workflow-aspire/3-workflow-definition` has no duration sentence at all — use the form above for a new track.
3. **A `> [!IMPORTANT]` callout** when the track has more than one terminal (see **tabs.md** below for the exact copy), or when the learner must not skip a precondition — "run this from inside *that* folder", "stop the app from the previous challenge first", "click *Check* before continuing".
4. **Numbered `## N. Title` steps**, each with its commands and its expected output.
5. **`---` and a one-line transition** naming what comes next — except on the last challenge, which closes with the section in **Closing the final challenge** instead.

Parts 2 and 3 look like this:

~~~markdown
In this challenge, you'll run two apps that have the same code and read from the same secret store. One of them reads a secret. The other asks for the same secret and is told no. This hands-on challenge takes about 8 minutes to complete.

> [!IMPORTANT]
> <the precondition the learner must not skip — on a multi-terminal track this is the Run-button callout, whose exact copy lives in **tabs.md** below>

## 1. Two apps, one store
~~~

A complete, current example: `dapr-secrets/2-component-and-parameters/assignment.md`.

## Multi-language assignment pattern

For tracks supporting several languages, repeat each language-specific step inside a collapsible block so the page stays scannable. Two things the blocks need and often lose: a `> [!NOTE]` lead-in before the first `<details>`, and — on a track with named terminals — a line inside each block saying which window to use.

~~~markdown
## 2. Run the applications

> [!NOTE]
> Expand the language-specific instructions to start the applications.

<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

```bash,run
cd dotnet/Demo2-Scoping
```

```bash,run
dapr run -f .
```

</details>
~~~

`dapr-secrets/3-secret-scoping/assignment.md` has the full three-language version. `dapr-workflow` uses a longer summary (`<summary><b>Run the .NET application</b></summary>`), `dapr-secrets` a bare one (`<summary><b>.NET</b></summary>`). Either reads fine — be consistent within a track.

## Choosing an annotation

The full table is in SKILL.md. Two things it doesn't have room for.

**A `,run` flag on a `bash` block is a promise.** `docsync/check_doc_sync.py` checks a fence only when its info string *starts with* `bash` and carries `run` (`_is_run_fence`: `parts[0] == "bash" and "run" in parts`). Every such block must appear in the neighbouring robot suite, so adding `,run` to a `bash` block commits you to covering that command in a test (see **Drift testing** below).

**Nothing else is checked** — `shell,run`, `curl,run` and `<lang>,run` are invisible to doc-sync. That is a gap, not a licence: those commands still belong in the suite, there is just no job that will tell you when they don't. Prefer `bash` over `shell` for a new track so the checker covers you. And a block the learner reads but never executes should not carry `run` at all — that is the correct annotation, not laziness.

**Strays in the tracks — do not copy these.** They are mistakes that predate the convention, not patterns:

- `` ```output `` in `dapr-101/2-dapr-cli` — not a language; should be `text,nocopy`.
- Bare `` ```txt ``, `` ```text ``, `` ```python ``, `` ```java ``, `` ```csharp `` wrapping *output* in `dapr-workflow` — should carry `,nocopy`.
- `` ```bash,nocopy `` wrapping YAML in `dapr-101/4-service-invocation-api` — should be `yaml,nocopy`.

## Closing the final challenge

The last challenge's `assignment.md` still ends with `---`; what follows it is a recap and a closing section rather than a transition, because there is nothing to transition to. In this order:

1. **A recap.** `dapr-secrets/4-swap-the-provider/assignment.md` is the model: a paragraph on what the learner just proved, then a numbered list with one bold-titled line per challenge in the track. Shorter tracks sometimes use a single `## Summary` paragraph (`dapr-101/5-pubsub-api`).
2. **An H2**: `## Collect your badge & provide feedback` when the track has a Holopin badge (`dapr-101`, `dapr-workflow`), otherwise `## Feedback and further learning` (`dapr-workflow-aspire`, `dapr-secrets`).
3. **The congratulations sentence**, which must contain *"rate this training and provide feedback in the next step"* — Instruqt shows a rating step after the last challenge, and the sentence is what points the learner at it.
4. **The badge, where one exists**: the Holopin collect link as prose, then the badge image wrapped in the same link. The same image goes in challenge 1's `notes.md`. Holopin badges are created outside this repo, so **a new track has no badge until someone makes one — omit it rather than inventing a link.**
5. **Three bold sub-headings, in this order and spelling**: `**Try another university track**`, `**Read more**`, `**Join the community**`. Badge tracks put them under a `## Next steps` H2; the others keep them under the H2 from step 2.

What goes under each sub-heading:

- *Try another university track* — two sibling tracks, linked as `https://www.diagrid.io/university/<track-slug>`.
- *Read more* — the current State-of-Dapr report, plus one relevant Diagrid blog post or Dapr Docs page.
- *Join the community* — the Dapr Discord (`https://diagrid.ws/dapr-discord`), naming the channels that fit the track, and `https://www.diagrid.io/webinars`.

**Copy the current wording from the newest track rather than from this file.** The report year, the blog posts and the Discord channel names all change; the headings don't.

## tabs.md

Defines the IDE tabs the learner sees. Omit the file for a single-terminal track (a default terminal is provided). Each tab is a `## <Tab name>` section with key/value lines.

Terminal only:

```markdown
# Tab configuration

## Terminal

type: terminal
host: dotnet-10-aspire
path: dapr-workflow-aspire
```

Editor + Terminal + webapp (e.g. an Aspire/dashboard tab):

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

`host` must match the hostname used elsewhere (sandbox host, Instruqt-Var `hostname=`); both tracks that have the file use `dotnet-10-aspire`. `path` is normally the same in every section. Common tab types: `terminal`, `code editor`, `service/webapp`.

**`tabs.md` is optional, and new tracks should have one.** `dapr-101` and `dapr-workflow` have none — their language tabs are configured in the Instruqt UI, invisible to this repo and to code review. Every track added since (`dapr-secrets`, `dapr-workflow-aspire`, and the AI tracks) defines tabs here.

**Name terminals after what runs in them.** `dapr-secrets` uses `Editor`, `Dapr CLI` and `curl`, and the assignments then say "Use the **Dapr CLI** window to run the commands."

**A track with more than one terminal opens every `assignment.md` with this callout** — otherwise the learner runs a curl in the Dapr CLI window and gets a confusing failure:

```markdown
> [!IMPORTANT]
> When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.
```

**And name the window on every command that belongs to one** — "Use the **curl** window to ask the application for the `orderdb-password` secret:" — inside `<details>` blocks and outside them alike. The track-level callout tells the learner a dropdown exists; this is what tells them which entry to pick. `dapr-secrets/2-component-and-parameters/assignment.md` does it on each step.

## Images

Three conventions exist. **Use the first for a new track.**

1. **A per-challenge `images/` folder**, referenced as `https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/<track>/<challenge>/images/<file>.png?raw=true`. Only `dapr-workflow` does this, and it's the right one: the asset is in the repo, shows up in a PR, and the URL survives a track being re-created in Instruqt.
2. **An asset at the challenge root** with a `https://raw.githubusercontent.com/diagrid-labs/dapr-university-instruqt/refs/heads/main/<track>/<challenge>/<file>.png` URL — how `dapr-101` carries its badge. Works; just untidier.
3. **An Instruqt-hosted asset**, `https://play.instruqt.com/assets/tracks/<id>/<hash>/assets/<file>.png`, uploaded through the Instruqt UI — `dapr-workflow-aspire`. The image is **not in this repo**, so it can't be reviewed here and the link breaks if the track id changes. Avoid for new tracks.

`dapr-secrets` has no images at all; a text-only track is fine.

## _setup/sandbox-setup.sh

Runs at **every** sandbox launch — including a relaunch, and a learner may relaunch mid-track. **Write it so running it twice is safe.** Responsibilities: clone source code, log in to registries, install and initialize Dapr, set Instruqt variables, and pre-build anything slow.

The smallest form that still obeys that rule — a track needing only code and a version banner:

```bash
set -euo pipefail

[ -d "$HOME/quickstarts/.git" ] || git clone https://github.com/dapr/quickstarts.git "$HOME/quickstarts"
docker login -u ${DockerUSER} -p ${DockerPAT}

agent variable set DAPR_CLI_VERSION <pinned-cli-version>
agent variable set DAPR_RUNTIME_VERSION <pinned-runtime-version>
```

(`dapr-101/_setup/sandbox-setup.sh` is the same thing written before this convention: a bare `git clone` that fails on a relaunch. Don't copy it.)

The real one — `dapr-secrets/_setup/sandbox-setup.sh`, worth reading in full — adds five guards. Copy the ones your track needs:

1. `set -euo pipefail` at the top, so a failed clone doesn't leave a half-prepared sandbox that looks fine.
2. Clone only when the target has no `.git`.
3. `dapr init` only when the placement, scheduler and redis containers are not already running — with a `dapr uninstall` + `dapr init` retry if they still aren't up afterwards. Re-initializing a working sandbox tears down state the learner is using.
4. Install a tool only when `command -v` fails (and remember `uv` lands in `$HOME/.local/bin`, which isn't on `PATH` in that shell).
5. A dev-mode container (Vault, in that track) is removed and re-created rather than reused, so its state is the same on every run.

**Version pins live here and nowhere else.** When CI must use the same version, it parses it back out of this file — `tools/track-tester/ci/setup-dapr-secrets.sh` awks it out of the `agent variable set` lines. So keep those lines in plain `agent variable set NAME VALUE` form, and leave a comment saying why, or someone will "tidy" them into a shell variable and break CI silently.

## Per-challenge scripts

They live in `<challenge>/scripts/`. (`dapr-workflow-aspire/2-project-creation/setup.sh` sits at the challenge root and is empty — not a pattern.)

**`scripts/setup.sh` — must be self-sufficient.** A learner can jump straight to challenge 3 from Instruqt's *Progress* button, so this script may not assume `sandbox-setup.sh` or any earlier challenge ran. Model: `dapr-secrets/1-what-is-the-secrets-api/scripts/setup.sh` — it re-clones when the checkout is missing, re-creates generated files, and pre-builds the demo in **every** supported language so switching language mid-track isn't slow.

**`scripts/check.sh` — one branch per distinguishable failure.** Each calls `fail-message "<hint>"` and `exit 1`, ordered most-specific-first, and each hint names the action that fixes it ("Did you remove the `# ` in front of configFilePath in dapr.yaml, and restart `dapr run -f .` afterwards?"), not just the symptom. The happy path echoes a short success line. Model: `dapr-secrets/3-secret-scoping/scripts/check.sh`.

**`scripts/solve.sh` — actually solve it.** It applies the same edit the assignment asks for (a `sed` that's a no-op when already applied), stops whatever the learner left running so the ports are free, restarts in one language in the background with `nohup`, and polls until the app answers before exiting 0. Model: `dapr-secrets/3-secret-scoping/scripts/solve.sh`.

## _setup image install

Builds the **base VM image** the sandbox runs on. It is always a shell script that installs SDKs and CLIs, run by Instruqt when the image is built — **not** by GitHub Actions, and there is no Dockerfile anywhere in this repo. Four names are in use for the same thing: `image-<slug>-install.sh` (`dapr-101`, `dapr-workflow`, `dapr-secrets`), `image-install.sh` (`dapr-agents`), `image-definition.sh` (the AI tracks) and `vm-setup.sh` (`dapr-workflow-aspire`, `ai-agents-maf`). Prefer `image-<slug>-install.sh` for a new track.

Keep it in sync with what the assignments assume is preinstalled — a `,run` command whose tool isn't in this script fails for every learner.

```bash
# Install .NET 10
sudo add-apt-repository ppa:dotnet/backports
sudo apt-get update && sudo apt-get install -y dotnet-sdk-10.0
# Dapr CLI
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
# Aspire CLI
curl -sSL https://aspire.dev/install.sh | /bin/bash
source /root/.bashrc
```

A track doesn't have to build its own image: `catalyst-101` and `ai-agents-supply-chain-auditor-langchain` have only a `sandbox-setup.sh` and run on an image built elsewhere. If you reuse one, check that everything your assignments need is already installed by that image's script, and install the rest in `sandbox-setup.sh`.

Don't confuse the image with the **host name** in `tabs.md`. `dapr-secrets` and `dapr-workflow-aspire` both use `host: dotnet-10-aspire`, but `dapr-secrets` still has its own `image-dapr-secrets-install.sh`.

## Source-code models in depth

**A. Clone an external repo (preferred when code exists upstream).**
`sandbox-setup.sh` runs `git clone https://github.com/dapr/quickstarts.git`. Assignments instruct the learner to `cd` into specific example folders (e.g. `csharp/task-chaining`). Note that `dapr/quickstarts` uses a `resources/` folder for Dapr components (not `components/`) — match whatever the upstream repo uses. Keep pinned versions in `Instruqt-Var`s so the displayed output matches.

**B. Build it live.**
No app code is committed or cloned. The learner runs scaffolding commands (`dotnet new`, etc.) and pastes code from `,copy` blocks in the assignments. Use a `tabs.md` with a code-editor tab so they can see the files. This is heavier to author (every file's content lives in the assignment) but gives a "from scratch" narrative.

Either way, **do not commit a full application into this tracks repo** — it holds track definitions, instructions, setup scripts, and small assets (images), not application source. If new source code is genuinely needed, create/extend a separate examples repo and clone it.

## Secrets (AI / Catalyst tracks) in depth

Any track that calls an LLM (all AI-based tracks) or Catalyst needs a secret such as an OpenAI API key. **Never** bake a key into the VM image, `sandbox-setup.sh`, or any committed file. The learner supplies it themselves during the **first** challenge, via one of:

- **`.env` file** — commit a `.env.example` with empty/placeholder values; the assignment has the learner `cp .env.example .env` and paste their key. Keep the real `.env` git-ignored.
- **Shell environment variable** — the assignment has the learner `export OPENAI_API_KEY=...` in the terminal tab.

Announce the requirement in the track `README.md` teaser (e.g. add "Requires an OpenAI API key." to the Languages/Duration line) and validate it in `scripts/check.sh`. Example — fail the Check until a non-empty value is present:

```bash
if [ ! -f ".env" ]; then
    fail-message "No .env file found. Copy .env.example to .env and paste your OpenAI API key."
elif ! grep -qE '^OPENAI_API_KEY=.+' .env; then
    fail-message "OPENAI_API_KEY is empty in .env. Paste your key after the '=' sign."
fi
```

## Drift testing (Robot Framework)

Runnable tracks depend on upstream code and can silently drift out of sync with what the learner sees. The repo catches this with an end-to-end harness in `tools/track-tester/` (Robot Framework) that runs the *actual* `,run` commands from each `assignment.md` and asserts on their output. This — **not** `solve.sh` — is how a track is tested end-to-end. Read `tools/track-tester/README.md` before writing suites.

**Where the suite lives:**
- **Clone-an-external-repo tracks** (e.g. `dapr-101`, `dapr-workflow`): one suite per runnable challenge at `<track>/<n>-<slug>/tests/challenge.robot`, with test cases tagged per language (`dotnet` / `java` / `python` / `javascript`).
- **Build-it-live tracks** (e.g. `dapr-workflow-aspire`): a single track-level suite at `<track>/tests/challenge.robot` with one test case per challenge that reconstructs the app from the assignments and builds/runs it.

**Build-it-live suites pull commands out of the assignment at runtime** — `Get Command Containing ${ASSIGN} "aspire run"`, from `libraries/assignment_blocks.py` — so the assignment stays the single source of truth for an app that exists nowhere else. Only `dapr-workflow-aspire/tests/challenge.robot` does this, and it is the one track whose CI runs no doc-sync job.

**Per-challenge suites do the opposite: spell the commands out literally**, because doc-sync matches the suite text against the assignment and a command assembled from variables is invisible to it. That is the pattern in `dapr-101`, `dapr-workflow` and `dapr-secrets` — follow it unless you are writing a track-level suite for a build-it-live track.

Shared keywords live in `tools/track-tester/resources/`, shared values in `variables/`.

**doc-sync:** `tools/track-tester/docsync/check_doc_sync.py` asserts every runnable command in an `assignment.md` appears in its suite. Only fences whose info string *starts with* `bash` and carries `run` are checked — `shell,run` and `curl,run` are not — and it is a *presence* check — a substring search over the suite text, not proof the command executed.

A command the suite performs indirectly — via a `cwd=` argument, a `bash -c '… && …'`, or a keyword that builds the request — is declared in a **trailing comment block** at the end of the suite, one indented line per command:

```robot
# doc-sync coverage (expressed via cwd above):
#   cd dotnet/Demo1-ReadSecret
#   cd python/Demo1-ReadSecret
#   cd java/Demo1-ReadSecret
```

The parenthetical says *how* the suite really performs them — `(expressed via cwd / bash -c above)`, `(performed by ci/setup-dapr-101.sh, asserted above)`, `(the commands are run above through the Request and Start Background Process keywords)`. It is for the next human, not the checker: the checker would accept any comment at all, which is exactly why the block has to be kept honest by hand when you edit a suite.

**Suite conventions in the newer tracks** (model: `dapr-secrets/1-what-is-the-secrets-api/tests/challenge.robot`):

- An untagged `Port NNNN Is Free Before The App Starts` test, plus `[Setup] Wait For Port NNNN To Be Free` on every language case. A previous language's app can still be holding the port and answering — without this, one language's assertions can pass against another language's app.
- `[Teardown] Stop Process With SIGINT    app` on every case that starts something.
- A `Documentation` block on the suite, and on any test whose reason for existing isn't obvious from its name.
- `${LOG}    ${TEMPDIR}/<track>-ch<n>.log` for the background process log.
- Expected values as `*** Variables ***`, each with a comment naming where the value comes from (the component file, the assignment, the upstream repo) — so a drift failure points at the owner.
- `\%` where a command contains curl's `%{http_code}`, or Robot reads it as a variable.
- **Spell commands out literally**, not built from variables, so doc-sync can match them against the assignment text (per-challenge suites only — see above).

**CI workflow:** add `.github/workflows/test-<track>.yml`. Copy `test-dapr-workflow-aspire.yml` (build-it-live) or `test-dapr-workflow.yml` (multi-language matrix) and swap the track name/paths. Every workflow:
- triggers on a daily `schedule` (stagger the cron a few minutes off the others), `workflow_dispatch`, and `pull_request` touching `<track>/**`, `tools/track-tester/**`, and the workflow file;
- provisions language runtimes (`setup-dotnet`/`setup-java`/`setup-node`/`setup-python`) and the Dapr sandbox (`tools/track-tester/ci/setup-<track>.sh`), then runs the suite with `uv run robot`;
- has a `report` job (`if: failure()`) that opens/updates a `drift-report` labelled issue linking the failing run and the Robot artifact.

**Pick a free cron slot.** The four existing workflows run at 06:00 (`dapr-101`), 06:15 (`dapr-workflow`), 06:30 (`dapr-workflow-aspire`) and 06:45 (`dapr-secrets`) UTC. Take the next quarter hour.

**A language-agnostic leg.** When some tests aren't language-specific, add a `shared` matrix leg that inverts the language tags with `--exclude` (as `test-dapr-secrets.yml` does), so those tests run once instead of once per language.

**Name the step that broke.** A failure *before* the tests — sandbox setup, a seeded container, a version guard — should be recorded in `failed-<leg>.txt` too, so the drift-report issue says which step failed rather than implying a test did.

Each track also needs its own `tools/track-tester/variables/<track_with_underscores>.py` (e.g. `dapr_secrets.py` — a module name, so underscores, not the hyphens of the track folder; resolving the checkout from an env var with a `$HOME` fallback) and `tools/track-tester/ci/setup-<track>.sh` — there is one of each per runnable track today. Finally, add a row to the workflow table in the repo `README.md` (currently lines 39–44).

## Final pre-flight checks

What the Checklist in SKILL.md says must *exist*, this says must be *proven to work*. Run these, don't eyeball them.

- **doc-sync passes for every challenge.** `(cd tools/track-tester && uv run python docsync/check_doc_sync.py ../../<track>/<n>-<slug>/assignment.md ../../<track>/<n>-<slug>/tests/challenge.robot)`
- **The suites at least resolve.** `(cd tools/track-tester && uv run robot --dryrun ../../<track>/*/tests/challenge.robot)` — no Docker or Dapr needed.
- **The suites pass for real**, after running `tools/track-tester/ci/setup-<track>.sh`.
- **`solve.sh` then `check.sh` passes**, for every challenge that has the pair.
- **Every `,run` command works in the sandbox image** — anything it needs is installed by the image script, not assumed.
- **Challenge setup is order-independent:** starting the track at challenge *N* alone works, because each `scripts/setup.sh` stands on its own.
- **`sandbox-setup.sh` survives a second run** with the sandbox already prepared.
- **Durations** in the challenge intros sum to under the track `README.md` time limit.
- **Every `Instruqt-Var` key** used in an assignment is `agent variable set` in `sandbox-setup.sh`, and every `hostname=` matches a real host.
- **Any required secret** is set by the learner in challenge 1, announced in the teaser, validated by `check.sh`, and present in no committed file or image.
- **The image install script** covers every tool the assignments use, if the track introduces its own image.
