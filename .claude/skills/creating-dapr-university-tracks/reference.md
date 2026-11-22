# Reference: Instruqt 2.0 lab files

Templates and detail for `creating-dapr-university-tracks`. Load it when writing lab files. The two
reference labs are the source of truth: when this file and a lab disagree, the lab wins, and this
file needs a fix. Copy versions, commit SHAs, links and wording that change over time from the
newest lab, never from here. (Legacy 1.0 tracks: `legacy-1.0.md`.)

## Root files

Copy each file from `dapr-pubsub/` and change what is listed. Keep the comments in the HCL files:
they record why a setting is the way it is.

### main.hcl

The `lab` resource. Change `title`, the `description`, the chapter name and title, and the page
entries. The description has this shape, line for line:

```
In this self-paced track, you'll learn:
- <one bullet per page>

You'll probably need around <N> minutes to complete the <M> labs.

The sandbox is available for <limit> minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the track.

Complete the track to collect the Dapr University <topic> badge.

![Dapr University <topic> badge](<raw main URL of the badge image>)
```

`<N>` is the sum of the per-page estimates rounded down to a multiple of 5; `<limit>` matches `timelimit.duration`.
The last two lines exist only when a badge exists (see Images and badges). Keep `settings` as in
`dapr-secrets` (30m / extend 10m / `show_timer`, idle 10m / `show_warning`) unless the user approved
more. `layout = resource.layout.main`. Each page gets a `page "<snake_name>" { reference =
resource.page.<snake_name> }` entry, in order. A page that needs another layout sets
`layout = resource.layout.<name>` on its entry (`dapr-pubsub` page 6).

### pages.hcl

```hcl
resource "page" "subscription_types" {
  title = "Subscription types"
  file  = "1-subscription-types/assignment.md"
}
```

The `title` is the same text as the page's H1.

### layouts.hcl

Copy `dapr-secrets/layouts.hcl`, which has only the `main` layout. (`dapr-pubsub/layouts.hcl` also
has a `broker` layout for its RabbitMQ tab; drop it unless the new lab needs the same.) Instructions take the left 40; the right 60 has a top row with the **Dev Dashboard**
tab and then the **Editor** tab, and a bottom row with the **Dapr CLI** and **curl** terminals side
by side. The Editor is declared last with `active = true`, because declaring it first did not make
it open by default. Both terminals stay visible because Run buttons only send commands to a terminal
that is shown on the page.

A service tab that only works from a later page on (RabbitMQ, started on `dapr-pubsub` page 6) goes
in a second layout that differs only in that tab, so earlier pages don't show a "trying to connect"
tab. Set it on that page's entry in `main.hcl`.

### tabs.hcl

Copy `dapr-secrets/tabs.hcl` (dapr-pubsub's adds a `rabbitmq` service; drop it) and change the folder in both terminals' `working_directory`
(`/root/university-labs/<folder>`). That folder only holds on page 1: terminals keep
their folder across pages, which is why every run section starts with the anchored `cd` (SKILL.md →
State carries over between pages). It defines `service "editor"` (code-server on port
8888), `service "dev_dashboard"` (port 9090, with the `Host` and `Origin` custom request headers the
Dev Dashboard needs, see the comment), and the `terminal "dapr_cli"` and `terminal "curl"`
resources. Add a `service` for any extra tab, targeting `module.sandbox.output.vm`.

### versions.hcl

```hcl
variable "dapr_runtime_version" {
  description = "..."
  default     = "<copy from the newest lab>"
}

variable "tracks_src_ref" {
  description = "Commit of diagrid-labs/university-labs that the lab checks out after cloning."
  default     = "<commit with this lab's demo apps>"
}

module "sandbox" {
  source  = "diagrid/dapr-sandbox"
  version = "<exact published version, copy from the newest lab>"

  variables = {
    dapr_runtime_version = variable.dapr_runtime_version
    demo_repo_ref        = variable.tracks_src_ref
    editor_folder        = "<folder>"
    lab_startup_script   = file("scripts/lab-setup.sh")
  }
}
```

Copy the comments from `dapr-pubsub/versions.hcl` too. Rules (full version in `AGENTS.md`): keep
each pin a plain `variable` block, because `tools/track-tester/ci/read_pin.py` parses them; each pin
lives in exactly one file; `dapr_runtime_version` equals `prewarm_dapr_runtime_version` in
`modules/dapr-sandbox/versions.hcl`; the module version must be published in Instruqt before a lab
pins it. Add `demo_repo_url` only when the demo apps are not in `university-labs`.

### README.md (optional)

A human file map of the lab, as `dapr-secrets/README.md`. Not config; Instruqt ignores it.

## website-description.md

Prose, no headings, about four short paragraphs: a hook, what the learner does, the turn, what they
walk away knowing. Model: `dapr-pubsub/website-description.md`.

## lab-setup.sh

Copy `dapr-pubsub/scripts/lab-setup.sh` and keep its header comment. The contract:

- The module builds the VM startup script as
  `( export <inputs>; source /usr/local/lib/dapr-sandbox/sandbox-setup.sh; <this script> )` under
  `set -euo pipefail`. When this script starts, Docker, DNS, the demo clone at the pinned ref, the
  Editor, the Dev Dashboard and `dapr init` are already done.
- Available: `log`, `die`, `bounded`, `wait_for_docker`, `TRACKS_SRC_DIR`, `LAB_SETUP_LOG`.
  `exit` only leaves the subshell. Never touch the ready marker (`/var/lib/lab-setup/ready`).
- Only this lab's own steps. Safe to run again.
- The demo pre-build runs as a fully detached background job (`nohup bash -s … >>"$PREBUILD_LOG"
  2>&1 <<'PREBUILD' &`, each build with `</dev/null`), logs to `/var/log/lab-prebuild.log`, builds
  page 1's demo first, and never fails the lab.
- A service every page needs from the start is started and seeded here (Vault in `dapr-secrets`).
  A service only a later page needs is started from that page's Run block instead.
- The lab's files are not on the VM. A helper script is concatenated in front:
  `lab_startup_script = "${file("scripts/seed-vault.sh")}\n${file("scripts/lab-setup.sh")}"`
  (`dapr-secrets`), and `lab-setup.sh` falls back to sourcing it from its own folder for local runs.

## Page anatomy

### Every page

1. **H1** with the page title, identical to `pages.hcl`.
2. **Intro**: "In this lab, you'll <what>. This hands-on lab takes about <N> minutes to complete."
3. **Opening for pages after page 1**, one of:
   - `## Before you start` when the page starts its own apps: "The terminals, and the applications
     running in them, stay as they are when you move between labs. Open the **Dev Dashboard** tab
     and look at which applications are running. If any are, … use the **Dapr CLI** window to stop
     them by pressing `Ctrl+C`. Then go back to the **Editor** tab." (`dapr-pubsub` pages 2 to 6)
   - A "Check that the application is running" section with an "If the application is not running"
     fallback that restarts it, when the page keeps the previous page's app
     (`dapr-secrets/2-component-and-parameters`).
4. **Numbered sections** `## 1. Title`, `## 2. Title`, …
5. **The run section** (the first section with Run blocks), in this order:

   ```markdown
   > [!IMPORTANT]
   > When you use the *Run* button on a command, select the matching terminal from the dropdown that appears.

   Use the **Dapr CLI** window to go to the `<folder>` folder first. The terminal stays in whatever folder it was in when you move between labs, so this makes sure the commands below start from the right place:

   ```bash,run
   cd /root/university-labs/<folder>
   ```

   > [!IMPORTANT]
   > Run `dapr run -f .` from inside the demo folder of your language: `<DotnetFolder>` for .NET, `<kebab-folder>` for Python and Java. <why, e.g. the resourcesPaths in dapr.yaml are relative to that folder>.
   ```

   Then the per-language `<details>` blocks (see Multi-language pattern) and a `###` line. On page 1
   only, directly after the `###` (so after the `dapr run` commands, never before them):

   ```markdown
   > [!NOTE]
   > When the apps start, the Editor shows a popup saying *Your application running on port `<number>` is available*. Close the popup, or click the settings gear to dismiss it. There is no UI to open, so don't click *Open in Browser*.
   ```

   Then:

   ```markdown
   > [!IMPORTANT]
   > Wait until <the apps> are running before continuing. The Java applications can take a little longer to start.
   >
   > Open the **Dev Dashboard** tab and check the application health on the **Applications** page: <apps> are ready when the **Health** column shows a green dot. You can also inspect the output of the **Dapr CLI** window.
   ```

   followed by the expected "Started Dapr with app id" lines as `text,nocopy`.

   The Run-button callout goes on every page that has Run blocks, at the top of the first such
   section and before the sentence that introduces the first command. The anchored `cd` comes
   before any relative `cd`; `check_doc_sync.py --require-anchored-cd` fails otherwise.
6. **Commands**: name the window on each ("Use the **curl** window to send an order…"). JSON
   responses end in `| jq`, and the expected output is a `json,nocopy` block after "Expected
   output:". Logs: the **Dev Dashboard** Logs page (pick the app, type a search term), not `tail`.
7. **Callouts**: `[!IMPORTANT]` only for things the learner must do or must not skip; `[!NOTE]` for
   asides (and the "Expand the language-specific instructions" lead-in); `[!WARNING]` for caveats
   such as an alpha API. No INFO type exists.
8. **Containers a page starts**: remove any existing one first, so the block is safe to run again,
   and say so (`dapr-pubsub` page 6):

   ```bash
   docker rm -f rabbitmq >/dev/null 2>&1 || true
   docker run -d --name rabbitmq … <image>
   ```

   "The first line removes an existing container, so you can run this block again whenever you
   like."
9. **Last numbered section**: `## N. Stop the applications` with "Use the **Dapr CLI** window to stop
   the applications by pressing `Ctrl+C`." Leave it out only when the next page reuses the running
   app; then that page's "What's next?" says the app keeps running (`dapr-secrets` page 1), and the
   next page opens with the "is it running" check.

### End of a middle page

```markdown
---

<One sentence on what the learner just did.>

## What's next?

In the next lab you'll <what>.
```

### The final page

- Intro: "In this final lab, you'll <what>. This hands-on lab takes about <N> minutes to complete.
  At the end of the lab, you can claim the Dapr University Holopin badge for this track." (the last
  sentence only with a badge).
- After the last section: `---`, a paragraph on what the learner proved, "Here is what you did in
  this track:" and a numbered list with one `**<Page title>:** <what you did>` line per page.
- `## Collect your badge & provide feedback` (or `## Feedback and further learning` without a badge),
  then "Congratulations! 🎉 You've completed the Dapr University <topic> learning track! Click
  **Finish & Exit** below to finish the lab 🚀."
- With a badge: "Collect the Dapr University badge for this track by following [this link to the
  Holopin platform](<link>). You'll need a GitHub account to claim the badge." and the badge image
  wrapped in the same link.
- `## Next steps`, "We have more opportunities for you to learn and share knowledge:", then the bold
  sub-headings **Try another university track**, **Try these Dapr tools**, **Join the community**,
  each with the bullets copied from the newest lab's final page.
- Last line: `<instruqt-completion text="You've completed <short lab title>!"></instruqt-completion>`.

## Multi-language pattern

One `<details>` block per language, with the language's own folder and the window named inside:

````markdown
<details>
   <summary><b>.NET</b></summary>

Use the **Dapr CLI** window to run the commands.

Navigate to the *dotnet/Demo1-Subscriptions* folder:

```bash,run
cd dotnet/Demo1-Subscriptions
```

Run the three applications using the Dapr CLI:

```bash,run
dapr run -f .
```

</details>
````

Summaries are `<b>.NET</b>`, `<b>Python</b>`, `<b>Java</b>`. Folder names follow each language:
PascalCase for .NET (matching the `.csproj`), kebab-case for Python and Java. Wherever one sentence
outside the blocks names a folder, give both forms. Suites and scripts map the language to its
folder explicitly (the per-language dicts in `tools/track-tester/variables/dapr_pubsub.py`), never
by building one name.

With fewer languages (user's choice): one language means no `<details>` at all and one folder
spelling; two languages means two blocks. The suite tags and CI matrix legs shrink to match.

## Images and badges

- Put images in the page's `images/` folder and reference them as
  `https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/<lab>/<n>-<slug>/images/<file>.png?raw=true`,
  with alt text that describes the diagram. They render only after the merge to `main`.
- Diagrams with a transparent background get flattened onto white, so dark lines stay visible on a
  dark theme (any image tool works, for example Pillow: `alpha_composite` onto a white `RGBA` image,
  saved as `RGB`).
- Badges are made outside this repo (Holopin). Until the user supplies the collect link and the
  image, leave out all three badge parts: the badge lines in `main.hcl`, the badge sentence in the
  final page's intro, and the badge block in its closing. The badge image goes in the final page's
  `images/` folder (`Diagrid-Dapr-Uni-badge-<topic>_x300.png`).

## Demo apps and sandbox content

- Demo apps live in `diagrid-labs/university-labs` under `<folder>/`, as
  `dotnet/DemoN-PascalCase/`, `python/demoN-kebab-case/` and `java/demoN-kebab-case/`. Each demo
  folder has a `dapr.yaml` Multi-App Run file and a `resources/` folder. Pin the commit as
  `tracks_src_ref`. Never commit demo code to this repo.
- The sandbox image provides the toolchain (Docker, Dapr CLI, .NET, JDK and Maven, Python and uv,
  Node, jq, git, code-server, Dev Dashboard) and pre-pulls container images
  (`modules/dapr-sandbox/scripts/install-tools.sh` and `prewarm.sh`).
- **Every container image a lab runs must already be in the sandbox image**, wherever the lab starts
  it (`lab-setup.sh` or a page's Run block). RabbitMQ and Vault are pre-pulled by `prewarm.sh`, so
  their `docker run` prints no pull progress. Never let a learner wait for a `docker pull`, and never
  pull at boot in `lab-setup.sh` to work around a missing image.
- **Anything the image lacks is a module change**, not a boot step: edit the module scripts, rebuild
  the image, set `image_ref`, publish a new module version in Instruqt, then pin it in the lab. Only
  the owner can build and publish, so raise it with the user early and point to "Toolchain bump" in
  `docs/instruqt-2-runbook.md`. A value that must agree across files (an image tag in a page, in
  `prewarm.sh` and in the variables file) gets a pytest like
  `tools/track-tester/ci/tests/test_pubsub_pins.py`.
- **API keys** (an LLM or Diagrid track): the learner supplies the key on page 1 with a `.env` file
  or `export`, never baked into the image, scripts or repo, and the `main.hcl` description says the
  track needs one. There are no page checks, so the page shows how to verify the key. Untested in a
  2.0 lab so far: neither reference lab needs a key.

## Drift tests and CI

Read `tools/track-tester/README.md` and `AGENTS.md` ("The track-tester harness") first. A new lab
adds, each modelled on its `dapr-pubsub` counterpart:

- **`<n>-<slug>/tests/challenge.robot`** for every page with Run blocks. Model:
  `dapr-pubsub/3-cloudevents/tests/challenge.robot`.
  - `Resource ../../../tools/track-tester/resources/dapr.resource` and
    `Variables ../../../tools/track-tester/variables/<lab_with_underscores>.py`.
  - A suite `Documentation` block, `Suite Teardown Terminate All Processes kill=True`,
    `${LOG} ${TEMPDIR}/<lab>-ch<n>.log`.
  - An untagged ports-are-free test, then one test per language tagged `dotnet`, `python` or
    `java`, each with `[Setup]` waiting for the ports and `[Teardown] Stop Process With SIGINT app`.
  - Expected values as `*** Variables ***` with a comment naming where each value comes from.
  - `\%` where a command contains curl's `%{http_code}`.
  - A trailing comment block for commands the suite runs indirectly (via `cwd=`, a keyword that
    builds the command, or a unique ID instead of the page's sample ID):

    ```robot
    # doc-sync coverage (<how the suite really runs them>):
    #   cd /root/university-labs/<folder>
    #   cd dotnet/Demo1-Subscriptions
    #   dapr run -f .
    ```

    doc-sync is a presence check over the suite text, so keep this block honest by hand.
- **`tools/track-tester/variables/<lab_with_underscores>.py`**: `TRACKS_SRC_DIR` from the
  environment with a `~/university-labs` fallback, the lab base path, and per-language
  folder dicts.
- **`tools/track-tester/ci/setup-<lab>.sh`**: reads the pins with `read_pin.py` (Dapr CLI from
  `modules/dapr-sandbox/versions.hcl`, runtime and `tracks_src_ref` from the lab's `versions.hcl`),
  clones the demo repo at the pinned commit, installs the Dapr CLI and `uv`, runs `dapr init` when
  needed, and starts any lab service.
- **`.github/workflows/test-<lab>.yml`**: copy `test-dapr-pubsub.yml`. It has a `changes` path gate,
  a doc-sync job running `check_doc_sync.py --require-anchored-cd` per page, a language matrix plus a
  `shared` leg (inverting the language tags with `--exclude`), an aggregate `<lab>-result` job, and
  a `report` job for the `drift-report` issue. Pick the next free daily schedule slot by reading the
  existing workflows.
- **`.github/workflows/lab-validate.yml`**: add the lab to the format, referenced-files
  (`check_lab_paths.py`), validate (`validate-lab.sh`) and shellcheck loops.
- **`tools/track-tester/ci/tests/test_read_pin.py`**: add the lab's `versions.hcl` to `REAL_PINS` and
  the lab to the `test_prewarm_runtime_pin_matches_lab_runtime_pin` parametrize list.
- **Docs**: the track table and CI table in `AGENTS.md`, and the track list and workflow table in
  the repo `README.md`.

## Local validation

Run these before saying the lab is done, from the repo root unless noted:

- `tools/track-tester/ci/validate-lab.sh <lab> modules/dapr-sandbox` (plain `instruqt lab validate`
  cannot resolve the registry module)
- `python3 tools/track-tester/ci/check_lab_paths.py <lab>` and the `instruqt lab format` check, as
  `lab-validate.yml` runs them
- `shellcheck <lab>/scripts/*.sh`
- doc-sync per page:
  `(cd tools/track-tester && uv run python docsync/check_doc_sync.py --require-anchored-cd ../../<lab>/<n>-<slug>/assignment.md ../../<lab>/<n>-<slug>/tests/challenge.robot)`
- `(cd tools/track-tester && uv run robot --dryrun ../../<lab>/*/tests/challenge.robot)`
- with Docker: `bash tools/track-tester/ci/setup-<lab>.sh`, then the suites for real
- `(cd tools/track-tester && uv run pytest -q)`
- the per-page minutes, rounded down to a multiple of 5, match the `main.hcl` line, under the time limit

## Owner hand-off

Only the repo owner can do these; tell the user they are pending and point to
`docs/instruqt-2-runbook.md` ("Checkpoint B: dapr-pubsub lab" is the model for a new lab, "Toolchain
bump" for an image change):

- build the image and publish a new module version, if the lab needs something the image lacks
- create the lab in Instruqt, connected to `main` with the lab folder as root directory
- add `<lab>-result` to the required checks on `main`
- a timed play-through against the time limit
- create the Holopin badge
- embed the lab on the Dapr University site
