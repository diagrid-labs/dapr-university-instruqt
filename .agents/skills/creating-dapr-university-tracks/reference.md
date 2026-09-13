# Reference: Dapr University track files

Full templates and details for `creating-dapr-university-tracks`. Load this when actually writing track files.

## Reference tracks to copy from

| Track | Languages | Source-code model | Notable conventions |
|---|---|---|---|
| `dapr-101` | .NET/Python/Java/JS | Clones `dapr/quickstarts` in sandbox-setup | Numbered steps, Instruqt-Var versions, `scripts/check.sh`+`solve.sh`, badge image in notes |
| `dapr-workflow` | .NET/Java/Python | Clones `dapr/quickstarts` | Heavy `<details>` per-language blocks, `images/` diagrams, 11 challenges (legacy — longer than the 4–5 default) |
| `dapr-workflow-aspire` | .NET only | Build-it-live (learner scaffolds) | `tabs.md` with Editor/Terminal/Aspire webapp tabs, custom VM image, `,copy` code blocks |

When the new track resembles one of these, copy its closest challenge folder and adapt rather than starting from scratch.

## website-description.md (optional, newer tracks)

Marketing copy rendered on the Dapr University site. Free-form Markdown with sections like:

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

## notes.md template

Shown beside the **Start** button while the sandbox boots. Keep it short.

```markdown
Click the *Start* button to setup the sandbox environment for this training, this may take up to 2 minutes. Once the environment is ready, click the *Start* button again.

- There are <N> challenges to complete, each takes about 5 minutes. If your session is idle for more than 10 minutes, the session will stop and you'll need to restart the track.
- You can extend the time with 10 minutes if you run out of time.
- Tracks can be restarted up to 5 times.

---
In this challenge, you'll:
- <bullet>
- <bullet>

If you have any questions or feedback about this track, let us know in the *#university* channel of the [Dapr Discord server](https://bit.ly/dapr-discord).
```

The first challenge's `notes.md` usually carries the full intro + (optionally) a badge image. Later challenges can have a shorter `notes.md`.

## assignment.md full example (single language)

```markdown
# The Dapr CLI

The Dapr CLI is used during local development to run apps with a sidecar.

**In this challenge you'll download the Dapr CLI, initialize Dapr, and verify the installation. This takes about 5 minutes.**

## 1. Download the Dapr CLI

\```bash,run
wget -q https://raw.githubusercontent.com/dapr/cli/master/install/install.sh -O - | /bin/bash
\```

## 2. Verify the version

\```bash,run
dapr --version
\```

Expected output:

\```text,nocopy
CLI version: [[ Instruqt-Var key="DAPR_CLI_VERSION" hostname="dapr-uni-vm" ]]
Runtime version: [[ Instruqt-Var key="DAPR_RUNTIME_VERSION" hostname="dapr-uni-vm" ]]
\```

> [!IMPORTANT]
> Click the *Check* button to verify Dapr is installed before continuing.

---

You've installed Dapr. Next, you'll use the State Management API.
```

(Replace `\`\`\`` with real triple backticks — escaped here only to keep this code block intact.)

## Multi-language assignment pattern

For tracks supporting several languages, repeat each language-specific step inside a collapsible block so the page stays scannable:

```markdown
## 2. Run the workflow app

> [!NOTE]
> Expand the language-specific instructions to start the application.

<details>
   <summary><b>Run the .NET application</b></summary>

\```bash,run
cd csharp/task-chaining
dapr run -f .
\```

</details>

<details>
   <summary><b>Run the Python application</b></summary>

\```bash,run
cd python/task-chaining
dapr run -f .
\```

</details>
```

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

`host` must match the hostname used elsewhere (sandbox host, Instruqt-Var `hostname=`). Common tab types: `terminal`, `code editor`, `service/webapp`. Multiple terminals are common (e.g. a "Dapr CLI" terminal and a "curl" terminal) — give each its own `## <Name>` section.

## _setup/sandbox-setup.sh

Runs at **every** sandbox launch. Responsibilities: clone source code, log in to registries, initialize Dapr, and set Instruqt variables consumed by `Instruqt-Var` in assignments.

```bash
git clone https://github.com/dapr/quickstarts.git
docker login -u ${DockerUSER} -p ${DockerPAT}

agent variable set DAPR_CLI_VERSION 1.17.0
agent variable set DAPR_RUNTIME_VERSION 1.17.0
```

For build-it-live tracks, this may just create a working dir, `docker login`, `dapr init`, and pull any dashboard image:

```bash
mkdir <track-slug>
docker login -u ${DockerUSER} -p ${DockerPAT}
dapr init
docker pull ghcr.io/diagridio/diagrid-dashboard:latest
```

## _setup image install

Builds the **base VM/container image** the sandbox runs on. Two patterns exist in this repo:

1. **Install script** `image-<slug>-install.sh` (or `vm-setup.sh`) — shell script that installs SDKs/CLIs. Example installs Docker, .NET, Java, Node, Python, the Dapr CLI, etc. Keep this in sync with what the assignments assume is preinstalled.

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

2. **Dockerfile** in `_setup/` built and pushed to GHCR by a GitHub Actions workflow (newer tracks). The workflow triggers on changes under `<track>/_setup/**`, builds `context: <track>/_setup`, and tags `latest`. The resulting image is referenced as the sandbox host image in Instruqt. See `.github/workflows/build-dapr-workflow-aspire-image.yml` for the canonical workflow; copy it and swap the track name/paths when a track needs its own image.

## Source-code models in depth

**A. Clone an external repo (preferred when code exists upstream).**
`sandbox-setup.sh` runs `git clone https://github.com/dapr/quickstarts.git`. Assignments instruct the learner to `cd` into specific example folders (e.g. `csharp/task-chaining`). Note that `dapr/quickstarts` uses a `resources/` folder for Dapr components (not `components/`) — match whatever the upstream repo uses. Keep pinned versions in `Instruqt-Var`s so the displayed output matches.

**B. Build it live.**
No app code is committed or cloned. The learner runs scaffolding commands (`dotnet new`, etc.) and pastes code from `,copy` blocks in the assignments. Use a `tabs.md` with a code-editor tab so they can see the files. This is heavier to author (every file's content lives in the assignment) but gives a "from scratch" narrative.

Either way, **do not commit a full application into this tracks repo** — it holds track definitions, instructions, setup scripts, and small assets (images), not application source. If new source code is genuinely needed, create/extend a separate examples repo and clone it.

## Final pre-flight checks

- Durations in challenge intros sum to < 30 min and match the track `README.md` time limit.
- Every `,run` command actually works in the sandbox image (tools installed in the image script).
- Every `check.sh` has a matching `solve.sh`; running `solve.sh` then `check.sh` passes.
- All `Instruqt-Var` keys used in assignments are `agent variable set` in `sandbox-setup.sh`, and `hostname=` matches a real host.
- Image-build CI added/updated if the track introduces a new `_setup` image.
