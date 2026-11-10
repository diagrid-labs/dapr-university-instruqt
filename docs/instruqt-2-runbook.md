# Instruqt 2.0 admin runbook: dapr-secrets lab

Audience: the track owner, who has Instruqt admin rights and GitHub admin rights for
`diagrid-labs/dapr-university-instruqt`, and does every step by hand. Instruqt team slug: `diagrid`.

Do the sections in order. Section 1 to 7 prepare things; nothing is reachable by learners until
section 12 (embed), so merging early is safe.

**About UI paths.** Menu, field and button names were checked against https://docs.labs.instruqt.com/
on 2026-11-10 but have not been clicked through; steps marked *(docs, not verified)* are the ones
whose exact wording the docs do not spell out. If your UI differs, look for the closest menu with
the same name, do the equivalent, and write the real path next to the step. Facts about what Instruqt does
(module import reads the default branch, versions are cut in the UI, no CLI publish) are listed
in `docs/instruqt-2-spike-checklist.md`, Part 1.

**Pins used in this runbook** (all live in the repo, never repeat them elsewhere):

| Pin | Value | File |
| --- | --- | --- |
| Dapr CLI | the value of `dapr_cli_version` | `modules/dapr-sandbox/versions.hcl` (`dapr_cli_version`) |
| Pre-pulled Dapr runtime | the value of `prewarm_dapr_runtime_version` | `modules/dapr-sandbox/versions.hcl` (`prewarm_dapr_runtime_version`) |
| Lab Dapr runtime | the value of `dapr_runtime_version` | `dapr-secrets/versions.hcl` (`dapr_runtime_version`) |
| Demo repo commit | full SHA | `dapr-secrets/versions.hcl` (`tracks_src_ref`) |
| Module version used by the lab | the value of `version` | `dapr-secrets/versions.hcl` (`module "sandbox"`, `version`) |
| Image the VM boots from | `diagrid/<image-name>:<tag>` | `modules/dapr-sandbox/versions.hcl` (`image_ref`) |

---

## 1. Authorize the Instruqt GitHub App

Instruqt reads the repo through its GitHub App. Needed for module import, lab import and branch
previews.

1. Instruqt management interface, team `diagrid`: **Integrations** -> **Version control**
   (`/manage/diagrid/version-control`). Not the sidebar's other "Integrations" section, which is
   for LTI and webhooks.
2. Click **Add GitHub account**. This installs the Instruqt GitHub App on a GitHub organization;
   pick `diagrid-labs`.
3. On GitHub, limit the app's repository access to `diagrid-labs/dapr-university-instruqt` and
   confirm *(GitHub's own install screen; the Instruqt docs only say you "choose which
   repositories it can access")*.
4. Back in Instruqt, reload the Version control page.

If `diagrid-labs` was already added earlier, don't add it again: click **Configure on GitHub**
next to the account and add `dapr-university-instruqt` to the repositories the app can access.

**Expected:** `diagrid-labs` is listed with a connected state and `dapr-university-instruqt`
appears as an available repository when you reach the import screens in sections 7 and 9.
If the repository is missing from those screens, the GitHub App has no access to it: use
**Configure on GitHub** next to the account (step 4 above).

---

## 2. Build the `dapr-sandbox` image

The image holds Docker Engine, .NET SDK 10.0, JDK 17 + Maven, Python 3.12 + uv, Node.js 24 +
npm and the Dapr CLI (`dapr_cli_version`), with NuGet/Maven/uv caches warm and the container images pulled. It
must be built by hand: there is no CLI or API to build or publish images.

1. In a terminal on the feature branch (`feat/dapr-secrets-instruqt-2-lab`), from the repo root:

   ```bash
   modules/dapr-sandbox/scripts/render-image-script.sh > image.sh
   head -12 image.sh
   ```

   **Expected:** `image.sh` starts with `#!/usr/bin/env bash`, `set -euo pipefail` and the
   `export DOTNET_SDK_CHANNEL=10.0`, `JAVA_VERSION=17`, `NODE_MAJOR=24`,
   `DAPR_CLI_VERSION=<dapr_cli_version>`, `PREWARM_DAPR_RUNTIME_VERSION=<prewarm_dapr_runtime_version>`
   lines (values come from `modules/dapr-sandbox/versions.hcl`, for example `DAPR_CLI_VERSION=1.19.1`). If it fails, the message names the missing pin.
2. Instruqt sidebar: **Building blocks** -> **Images** -> **Create image**.
   - There is no name field here; the image is named when you publish (step 8).
   - Base image: under **System images** pick `ubuntu`, then **Version** `24.04`. Do not leave
     Version on the default **Latest**: `install-tools.sh` was tested on 24.04.
     (A `docker` system image with Docker Engine preinstalled also exists. Stay on `ubuntu`
     24.04: `install-tools.sh` installs Docker itself, and that is the combination that was tested.)
   - **Machine:** Large (options: Small, Medium (default), Large, Extra large).
   - **Disk:** 60 GB (range 20 to 500 GB, default 40 GB). The disk size carries into every VM
     booted from the image.
   - Click **Start building**.

   **Expected:** a build session opens with three panels: Terminal, Editor and Display. The
   session runs for at most two hours and is reclaimed after 15 minutes with no activity.
3. Get `image.sh` into the session. Pick one:
   - Open `image.sh` locally, copy its contents, create a file in the session's Editor panel
     (for example `/root/image.sh`) and paste.
   - Or put the file somewhere fetchable (for example a secret gist: `gh gist create image.sh`)
     and in the session terminal run `curl -fsSL <raw-url> -o /root/image.sh`. The script
     contains no secrets. Note `image.sh` is generated, so the raw file of the repo branch does
     not contain it.
4. In the session terminal, find where the file landed first. The terminal starts in `/`, and
   the Editor may save the file in `/` rather than `/root`, under whatever name you gave it:

   ```bash
   ls -l /*.sh /root/*.sh 2>/dev/null
   head -12 /root/image.sh   # use the path ls showed
   ```

   **Expected:** the first lines are the shebang, `set -euo pipefail` and the `export ...` pin
   lines from step 1. If they aren't, you pasted the wrong file. For example, `install-tools.sh`
   on its own stops with "ERROR: required environment variable ... is not set".
   Then run it by its full path and watch for errors:

   ```bash
   bash /root/image.sh 2>&1 | tee /root/image-build.log
   ```

   **Expected:** it finishes without error in well under the 2 hour limit (the cache pre-warm
   builds Demo1 and the two scoping apps in all three languages, so expect several minutes).
   Do **not** run `dapr init` and do **not** start any container or service: the Image Builder
   saves the state of running services into the image.
5. Verify the toolchain and the version block:

   ```bash
   dotnet --version; java -version; mvn -version; python3 --version; uv --version
   node --version; npm --version; dapr --version; docker --version
   ```

   **Expected:** .NET `10.0.x`, Java 17, Python 3.12, Node `v24.x`, the Dapr CLI at the value of `dapr_cli_version` in `modules/dapr-sandbox/versions.hcl`, a working
   Docker. (`dapr --version` prints the CLI version and `Runtime version: n/a` because `dapr init`
   has not run, which is correct.)
6. Verify that the pre-pull happened:

   ```bash
   docker images
   ```

   **Expected:** the list contains `daprio/dapr` with the tag from `prewarm_dapr_runtime_version` in `modules/dapr-sandbox/versions.hcl`, `redis`, `openzipkin/zipkin`
   and `hashicorp/vault` with tag `1.20`.
   If the images are missing: the script prints `WARNING: Docker daemon is not reachable` when the
   daemon was not up. Check `whoami` and `id` (is the session user root or in the `docker`
   group?) and `sudo docker info`. `install-tools.sh` installs Docker with `sudo sh get-docker.sh`
   and does not add the user to the `docker` group, so if the session user is not root the
   pre-pull needs `sudo docker pull <image>` (the images are daemon-wide, so that is fine). Pull
   the four images by hand with `sudo`, then record what you needed in `docs/instruqt-2-spike-checklist.md` (Item 3 finding).
   Do not publish an image without the pre-pull: the 1:30 start budget depends on it.
7. Optional: in the **Checkpoints** rail click **Create**. A checkpoint only lets you roll back
   within this build session; it is not a published version.
8. Click **Publish**. Enter **Image name** `dapr-sandbox`; the **Version** tag is prefilled with
   `v1`, keep it.
9. Write down the full image reference: `diagrid/dapr-sandbox:v1` (format
   `team-slug/image-name:tag`). You need it in section 3. Always keep the tag in the reference: an
   untagged reference resolves to the highest published version, so a later rebuild would change
   the lab without a commit.

**Expected:** the image shows as published under Building blocks -> Images, with a size. To
sanity check, a lab VM that uses it can run `docker images` and `dotnet --version` (this is also
spike Item 3 in `docs/instruqt-2-spike-checklist.md`).

---

## 3. Set `image_ref` on the feature branch

1. Edit `modules/dapr-sandbox/versions.hcl`: set the `default` of the `image_ref` variable from
   `ubuntu:24.04` to the reference from section 2 (for example `diagrid/dapr-sandbox:v1`).
2. Verify formatting and validity:

   ```bash
   instruqt lab format modules/dapr-sandbox && git diff --stat
   instruqt lab validate modules/dapr-sandbox
   tools/track-tester/ci/validate-lab.sh dapr-secrets modules/dapr-sandbox
   ```

   **Expected:** only `versions.hcl` changed; both validations print `[SUCCESS] Lab is valid`.
3. Commit only that file (explicit `git add`, so nothing unrelated is swept in), pushing happens in
   section 4 step 1:

   ```bash
   git add modules/dapr-sandbox/versions.hcl
   git commit -m "feat(modules): set dapr-sandbox image_ref"
   ```

   **Expected:** `git show --stat HEAD` lists only `modules/dapr-sandbox/versions.hcl`.

---

## 4. Verify CI on the pull request

CI has not run on this branch yet (nothing was pushed before this point).

1. Make sure the `image_ref` commit from section 3 step 3 exists (`git log -1 --stat`), then push
   the branch and open a pull request to `main`:

   ```bash
   git push -u origin feat/dapr-secrets-instruqt-2-lab
   gh pr create --base main --title "Instruqt 2.0 dapr-secrets lab" --body "See docs/instruqt-2-runbook.md"
   ```
2. On the PR's **Checks** tab wait for the workflows to finish.

   **Expected:**
   - `lab-validate` (workflow "Validate Instruqt labs", `.github/workflows/lab-validate.yml`) passes.
   - `dapr-secrets-result` (workflow "Test dapr-secrets track", `.github/workflows/test-dapr-secrets.yml`)
     passes. Its upstream jobs `docsync` and `languages (dotnet|java|python|shared)` run because the
     PR touches `dapr-secrets/**`; the Java leg is the slowest (up to 60 minutes).
   - If `languages` fails, open the failed leg's `robot-<lang>` artifact (`report.html`). A failure
     is often a real signal (see the repo `AGENTS.md`); fix before continuing.
3. Check that an unrelated PR does not run (or block on) the secrets tests. The throwaway PR must
   branch from the feature branch and target it (`--base`), not `main`: `main` does not have
   `lab-validate.yml` or the new `test-dapr-secrets.yml` yet, so a PR against `main` would run
   none of the new workflows and show nothing.

   ```bash
   git switch feat/dapr-secrets-instruqt-2-lab
   git switch -c throwaway/ci-skip-check
   echo "" >> dapr-101/README.md
   git add dapr-101/README.md
   git commit -m "throwaway: ci skip check"
   git push -u origin throwaway/ci-skip-check
   gh pr create --base feat/dapr-secrets-instruqt-2-lab --title "throwaway: ci skip check" --body "Delete me"
   ```

   **Expected:** `lab-validate` runs and passes. `dapr-secrets-result` passes while `docsync` and
   `languages (...)` show **Skipped** (the `changes` job found only `dapr-101/README.md` changed
   against the feature branch, nothing relevant).
4. Close the throwaway PR without merging and delete its branch:

   ```bash
   gh pr close throwaway/ci-skip-check --delete-branch
   git switch feat/dapr-secrets-instruqt-2-lab
   ```

---

## 5. Required status checks on `main`

You already created a ruleset on `main`. Edit it so it requires exactly two checks.

1. GitHub -> `diagrid-labs/dapr-university-instruqt` -> **Settings** -> **Rules** -> **Rulesets**
   -> open the existing ruleset for `main` -> **Edit**.
2. Under **Require status checks to pass**, make the list exactly:
   - `lab-validate`
   - `dapr-secrets-result`

   Remove any `languages (dotnet)`, `languages (java)`, `languages (python)`, `languages (shared)`
   or `docsync` entries. Those must not be required: a matrix job that is skipped by its `if` never
   reports its per-language check names, so the merge would wait forever.
3. A check name can only be added after it has run once in the repo, which section 4 did. If it
   is not offered in the picker, wait for the PR run to finish, or type the name and pick it from
   the search results.
4. Before saving, confirm both `lab-validate` and `dapr-secrets-result` actually appear in the
   check picker and are listed in the ruleset. They only appear after each has run once in the
   repo (section 4); if either is missing, stop, do not save a ruleset without it, and re-run
   section 4.
5. Save the ruleset (Enforcement status **Active**).

**Expected:** the PR from section 4 lists the two checks as **Required**. (Settings -> Branches
-> branch protection rules is the older equivalent: **Require status checks to pass before
merging**, same two names.)

---

## 6. Merge the pull request

Merge `feat/dapr-secrets-instruqt-2-lab` into `main` once both required checks are green.

**Expected:** `main` now contains `modules/dapr-sandbox/` and `dapr-secrets/` with the real
`image_ref`. This is safe: learners cannot reach the lab until you embed it (section 12).

Why it must be on `main` first: Instruqt reads the **default branch** of the repo when you import
a module and when you import the lab on branch `main`.

---

## 7. Import and publish the module `diagrid/dapr-sandbox` 1.0.0

1. Instruqt sidebar: **Building blocks** -> **Modules** -> **Import module**.
2. Choose the `diagrid-labs` account, then the repository `diagrid-labs/dapr-university-instruqt`.
   There is no branch to pick: the import reads the repository's default branch (`main`), which
   is why section 6 comes first.
3. **Module name:** `dapr-sandbox`. **Description:** "Ubuntu 24.04 VM with Docker, .NET, Java,
   Python + uv, Node and the Dapr CLI for Dapr University labs". **Module directory:**
   `modules/dapr-sandbox`. Leave **Publish to the community registry** off (visibility "Private:
   only this team", the default).
4. Open the imported module. Outside edit mode, click **Publish version** in the editor header and
   enter `1.0.0` (exactly `MAJOR.MINOR.PATCH`, all numeric).

**Expected:** the module is listed as `diagrid/dapr-sandbox` with version `1.0.0`. A version is
immutable: a later change to `modules/dapr-sandbox/` on `main` does **not** change `1.0.0`, and
Instruqt does not read versions from git tags. New content needs a new version cut by hand (see
"Toolchain bump").

The docs describe module import and lab import from subdirectories of a shared repository
separately, but not a module and a lab in the same repository. If the import is refused, record
the message in `docs/instruqt-2-spike-checklist.md` (Item 4 finding).

If the version you publish differs from `1.0.0`, change `version` in the `module "sandbox"`
block of `dapr-secrets/versions.hcl` to match, in a PR.

---

## 8. Secrets

None expected. The Docker Hub PAT (`DockerUSER`/`DockerPAT`) that the old track used is
intentionally **not** used any more: the daprio, redis, zipkin and vault images are pre-pulled
into the image, and a secret in a VM `environment` would be readable by learners. Do not create
team secrets for this lab (Building blocks -> Secrets stays untouched).

**Expected:** `grep -rn "DockerPAT\|DockerUSER" dapr-secrets/scripts dapr-secrets/*.hcl modules`
finds nothing. (Only the legacy `dapr-secrets/_setup/sandbox-setup.sh` still mentions them; the
2.0 lab does not use `_setup/`.)

---

## 9. Import the lab

Use **Import lab**, never **Connect repository**. Connect is for an empty repository or a lab
that already exists on the platform. Connecting a lab to this repository, which already has
content, makes Instruqt ask "Keep the lab's content" or "Keep the repository's content" and then
**Connect and overwrite** one side.

1. Instruqt: on the **Labs** page click **Import lab** (top right). The dialog is titled "Import
   lab from a Git repository".
2. Pick the `diagrid-labs` account from the dropdown, find `dapr-university-instruqt` and click
   **Select**. If the repository is not listed, the GitHub App has no access: see section 1.
3. Review the settings:
   - **Lab name:** prefilled from the repository name (`dapr-university-instruqt`). Change it to
     `dapr-secrets`.
   - **Branch:** `main` (defaults to the repository's default branch).
   - **Root directory:** change it from `/ (root)` to `dapr-secrets` (the directory that holds
     the lab's HCL files).
4. Click **Import lab**.
5. Importing drops you into edit mode. Leave it without publishing: open the **⋮** next to
   **Publish** and click **Exit edit mode**. Publishing from the UI would commit to `main`.

**Warning:** only a lab connected at the repository root (`/`) can be disconnected, so this one
never can. Check the root directory spelling before you confirm.

From now on, every push to `main` syncs to the lab and is validated on the platform (the docs:
"Every push deploys"). After a push, check the sync status on the lab's overview page; if it isn't
"Success", confirm you pushed to `main` and read the validation error. Don't edit content in the
Instruqt UI: **Publish** there commits back to the repository and creates a second place where
content is authored.

**Expected:** on the **Labs** page the lab shows sync status "Success" with a green checkmark
(the lab's overview page shows whether the latest push was picked up and whether validation
passed). The lab is titled "Dapr Secrets - Read, Scope, and Swap Secret Stores" with chapter
"Dapr Secrets" and four pages (What is the Secrets API; The component and its parameters; Secret
scoping; Swap the provider). The module `diagrid/dapr-sandbox` 1.0.0 resolves with no error in
the lab editor. If it does not, the module was not published (section 7) or the version differs
from `version` in `dapr-secrets/versions.hcl`.

---

## 10. Preview and acceptance play-through

### Previewing a branch

Use this whenever you change the lab, before merging.

1. Push the branch (`git push`).
2. In the lab editor, switch to the branch with the branch selector in the top bar.
3. Click **Play** in the top bar *(docs, not verified: the docs say each branch "can be launched,
   played, and previewed on its own", but don't describe Play after switching branches)*.

**Expected:** the branch plays independently of the live version. If a branch of this
sub-directory lab is not listed, record that in `docs/instruqt-2-spike-checklist.md` (Item 9
finding) and play the lab from `main` after merge instead.

### Acceptance play-through

Start a play with **Play** next to the lab on the **Labs** page (or **Play** in the lab's top
bar). While playing, **Go to creator dashboard** leaves the session running (the dashboard then
shows **Resume** and **Stop**); **Finish & Exit** ends the session and stops the sandbox. When the
lab setup or a check misbehaves, the **Logs** button in the lab's top bar shows the scripts'
output, which learners never see. The start-up script's output only appears there once the script
has ended, so while a start is slow or stuck, follow it on the VM instead (as soon as a terminal
opens): `tail -f /var/log/lab-setup.log` (timestamped setup steps, ending with `done after Ns`)
and `tail -f /var/log/lab-prebuild.log` (the demo builds, which run in the background after the
sandbox is ready).

Play the lab three times (see Timing). In each play go through all four pages in one language
(.NET, Python or Java), so that all three languages are covered by the end. Copy this checklist
into your notes per run.

Layout reminder: instructions on the left; on the right the **Editor** on top, with the **Dapr CLI**
and **curl** terminals side by side underneath it. The Editor shows the demo clone
(`/root/ai-agent-tracks-instruqt/secrets`); if it is empty, check `ls -ld /root` (needs the `x`
bit for others) and `cat /var/log/lab-setup.log` (should log "made … readable and writable for
the Editor tab").

| Page | .NET | Python | Java |
| --- | --- | --- | --- |
| 1. What is the Secrets API: instructions render, language `<details>` open, `bash,run` buttons paste into the terminal, Demo1 runs with `dapr run -f .` and the curl call returns the secret | [ ] | [ ] | [ ] |
| 2. The component and its parameters: edit the component in the Editor, save, rerun, the single and bulk calls and `secretKeyRef` step work | [ ] | [ ] | [ ] |
| 3. Secret scoping: app A reads `orderdb-password`, app B is refused (403) after enabling `configFilePath`, app B still reads `payments-api-key`; task check goes green | [ ] | [ ] | [ ] |
| 4. Swap the provider: the app in Demo3-SwapProvider reads `orderdb-password` from Vault; task check goes green | [ ] | [ ] | [ ] |

Also tick once per run: the Editor opens `/root/ai-agent-tracks-instruqt/secrets`; **Solve for
me** on the task on pages 3 and 4 runs the solve script and marks the task "Solved for you" (the
check is not run again after a solve); the **Finish & Exit** button on page 4 completes the lab; no page asks for a
credential; `env | grep -i -E "pat|token|password"` in the terminal shows nothing sensitive.

**Deliberate failures (once per run, on pages 3 and 4).** A failed check shows only the fixed
`failure_message` strings, one for every failing check (the script output goes to the lab logs,
not to the learner), so confirm the hints match the mistake:

- Page 3: do not remove the `# ` in front of `configFilePath` in `dapr.yaml`, then click
  **Check**. **Expected:** the failing condition "App B is refused orderdb-password" shows
  "App B is not refused orderdb-password with HTTP 403. If it can still read it, did you remove
  the '# ' in front of configFilePath in dapr.yaml, and restart 'dapr run -f .' afterwards? ...".
  Then fix it and confirm the check passes.
- Page 4: start the app from `Demo1-ReadSecret` instead of `Demo3-SwapProvider`, then click
  **Check**. **Expected:** the condition "Dapr loaded the Vault secret store" shows "The app isn't
  reading from Vault yet. Is secretstore-vault.yaml the component Dapr loaded? ...". Fix it
  and confirm the check passes.

If the learner sees nothing useful (no hint at all) record that as a finding: Instruqt may show
only a generic failure for conditions.

### Timing against 1:30

1. Stopwatch: start when you click **Start** on the lab's start screen. Stop when the first
   page is usable (instructions shown and the **Dapr CLI** terminal accepts a command).
2. Do **three runs**, each a fresh session. At least one must be a cold start: wait 10 minutes
   since the last run.
3. The target is **at most 1 minute 30 seconds** for every run.
4. In each run, also check the lab setup finished: in the terminal `ls /var/lib/lab-setup/ready`
   (exists once setup succeeded), `docker ps` (dapr_placement, dapr_scheduler, dapr_redis,
   dapr_zipkin and `vault` running) and `curl -s http://localhost:8200/v1/sys/health`
   (`"initialized":true`). `cat /var/log/lab-setup.log` shows how long each setup step took.
   The demo builds continue in the background: `tail /var/log/lab-prebuild.log` ends with
   `prebuild done` once they finish.
5. If a run is over 1:30, list what was slow (VM boot, image pull, `dapr init`, Vault seeding;
   the Logs show the VM boot as the gap between "Create" and "QEMU VM running") and look for what
   can move into the image or be dropped. Hot starts are the remaining option if the VM boot
   alone uses most of the budget.

### Record the results

Write the outcome (date, three times, languages covered, failed boxes, deviations in the UI
paths above) on the `Finding:` lines of Items 3, 5, 9 and 10 in
`docs/instruqt-2-spike-checklist.md`. Item 10 (the 1:30 timing) is the gate for the embed.

---

## 11. `INSTRUQT_TOKEN` (optional)

Only needed if you want `instruqt lab test diagrid/dapr-secrets` to run from CI or locally. No
workflow in the repo uses it yet, so skip this unless you add such a job.

1. Locally, `instruqt auth login` is enough. For CI you need a token: the team API key is under
   **Settings** -> **API keys** (only team Owners can see it; the eye icon reveals it,
   **Regenerate API Key** rotates it) *(docs, not verified: the docs describe this key for the
   GraphQL API and don't say it is the value `INSTRUQT_TOKEN` expects; confirm with one local run of
   `INSTRUQT_TOKEN=<key> instruqt lab test diagrid/dapr-secrets`)*.
2. For CI: GitHub -> repo **Settings** -> **Secrets and variables** -> **Actions** -> **New
   repository secret**, Name `INSTRUQT_TOKEN`, Value the token.
3. Run locally (needs the lab to be imported, section 9):

   ```bash
   instruqt lab test diagrid/dapr-secrets
   instruqt lab test diagrid/dapr-secrets --ref feat/dapr-secrets-instruqt-2-lab
   ```

**Expected:** exit code 0. For every task the check runs on the untouched task and must fail,
then the solve script runs and marks the task done (the check is not run again after the solve).
It tests the version on the platform for that branch, not your local files. `lab validate` and
`lab format` need no token.

---

## 12. Embed the lab and replace the old embed

1. In the lab editor click the **Share** icon in the header -> **Embeds** -> **New embed**.
2. Fill in:
   - **Name:** `diagrid-university`
   - **Lab version:** `main` (the default branch)
   - **Access window:** `24 hours` (options: 1 hour, 24 hours, 7 days, 30 days)
   - **Plays per end user:** **Limited** `1` (or **Unlimited** if learners need retries; legacy
     tracks allowed 5 starts)
   - **Embed expires:** `Never`
   - **Allowed sites:** the Diagrid University site origin, scheme and host with no path (for
     example `https://www.diagrid.io`)
3. Click **Create embed**. On the Share tab, copy the iframe snippet shown below the
   **Embed / Kiosk link** (**Copy link** copies only the link).
4. On the Diagrid University site, replace the old Dapr Secrets (legacy track) embed code with
   the new snippet, preview the page and start the lab once.

**Expected:** the iframe starts the lab without sign-in; a play beyond the plays limit, or from a
site that is not in Allowed sites, is refused. Record the snippet shape and any `icp_` parameter
you will want later in `docs/instruqt-2-spike-checklist.md` (Item 11 finding). URL parameters
starting with `icp_` set the lab variable of the same name without the prefix.

For the planned HubSpot-gated access, look at the other access options in the docs: the Embed /
Kiosk link can be shared directly, and there are also play tokens, lab access settings and an LTI
integration.

Do this only after Item 10 (timing) and the play-through are done.

---

## Maintenance procedures

### Toolchain bump

For a new .NET, JDK, Node, Dapr CLI or prewarmed runtime version.

1. Edit the pin in `modules/dapr-sandbox/versions.hcl` (`dotnet_sdk_channel`, `java_version`,
   `node_major`, `dapr_cli_version` or `prewarm_dapr_runtime_version`).
2. Render the image script: `modules/dapr-sandbox/scripts/render-image-script.sh > image.sh`.
3. Rebuild the image as in section 2 (steps 2 to 9). When publishing, choose the existing image
   `dapr-sandbox` and a new **Version** tag (for example `v2`).
4. Set `image_ref` in `modules/dapr-sandbox/versions.hcl` to the new reference.
5. Open a PR. `lab-validate` and `dapr-secrets-result` must pass; merge it.
6. Import/refresh the module and **Publish version** as the next number (for example `1.1.0`;
   section 7). The published `1.0.0` keeps the old image.
7. In `dapr-secrets/versions.hcl`, bump `version` in the `module "sandbox"` block to that number
   and merge by PR. Only after step 6: the merge syncs the lab, and a sync that pins a
   version that is not published yet fails with `failed to read hcl files: module "sandbox":
   version X of diagrid/dapr-sandbox is not published: not found`. Publishing afterwards does not
   clear that error; the lab only re-reads its HCL on the next push to `main` that changes a file
   under `dapr-secrets/`.
8. If you bumped `prewarm_dapr_runtime_version`, `dapr_runtime_version` in
   `dapr-secrets/versions.hcl` must equal it in the same change. The harness unit test
   `test_prewarm_runtime_pin_matches_lab_runtime_pin` (`tools/track-tester/ci/tests/test_read_pin.py`,
   run by `lab-validate`) fails the PR when they differ. See "Dapr runtime bump".
9. Preview the lab on the branch (section 10) before merging step 7.

### Demo repo bump

The lab and CI both use the same commit of `diagrid-labs/ai-agent-tracks-instruqt`.

1. Pick the new commit and copy its **full 40 character SHA**.
2. In `dapr-secrets/versions.hcl` set `tracks_src_ref` to it, in a PR.
3. CI tests that exact SHA (`languages` job, step "Read demo pin"). Merge when
   `dapr-secrets-result` is green.
4. If the new commit changes a demo's dependencies, rebuild the image so the caches match
   (Toolchain bump, steps 2 to 7): `prewarm.sh` clones the demo repo's default branch, not the
   pinned SHA.

### Dapr runtime bump

1. Set both pins to the new version: `dapr_runtime_version` in `dapr-secrets/versions.hcl` and
   `prewarm_dapr_runtime_version` in `modules/dapr-sandbox/versions.hcl`. They must be equal.
2. Rebuild the image so the new `daprio/dapr` tag is pre-pulled (Toolchain bump, steps 2 to 7).
3. Note how CI treats the runtime: `tools/track-tester/ci/setup-dapr-secrets.sh` runs an
   unpinned `dapr init` (what a learner gets today) and fails when the running runtime's
   MAJOR.MINOR differs from `dapr_runtime_version`. So a new Dapr minor turns the `languages`
   job red until you bump the pin, which is the intended signal.
4. Re-verify challenge 3's denial wording (403 `ERR_PERMISSION_DENIED`, 500 `ERR_SECRET_GET`)
   against the new runtime; `tools/track-tester/variables/dapr_secrets.py` holds the expected
   constants.
