# Instruqt 2.0 admin runbook: dapr-secrets lab

Audience: the track owner, who has Instruqt admin rights and GitHub admin rights for
`diagrid-labs/dapr-university-instruqt`, and does every step by hand. Instruqt team slug: `diagrid`.

Do the sections in order. Section 1 to 7 prepare things; nothing is reachable by learners until
section 12 (embed), so merging early is safe.

**About UI paths.** Menu names marked *(docs, not verified)* come from https://docs.labs.instruqt.com/
and have not been clicked through. If your UI differs, look for the closest menu with the same
name, do the equivalent, and write the real path next to the step. Facts about what Instruqt does
(module import reads the default branch, versions are cut in the UI, no CLI publish) are listed
in `docs/instruqt-2-spike-checklist.md`, Part 1.

**Pins used in this runbook** (all live in the repo, never repeat them elsewhere):

| Pin | Value | File |
| --- | --- | --- |
| Dapr CLI | the value of `dapr_cli_version` | `modules/dapr-sandbox/versions.hcl` (`dapr_cli_version`) |
| Pre-pulled Dapr runtime | the value of `prewarm_dapr_runtime_version` | `modules/dapr-sandbox/versions.hcl` (`prewarm_dapr_runtime_version`) |
| Lab Dapr runtime | the value of `dapr_runtime_version` | `dapr-secrets/versions.hcl` (`dapr_runtime_version`) |
| Demo repo commit | full SHA | `dapr-secrets/versions.hcl` (`tracks_src_ref`) |
| Module version used by the lab | `1.0.0` | `dapr-secrets/versions.hcl` (`module "sandbox"`, `version`) |
| Image the VM boots from | `diagrid/<image-name>:<tag>` | `modules/dapr-sandbox/versions.hcl` (`image_ref`) |

---

## 1. Authorize the Instruqt GitHub App

Instruqt reads the repo through its GitHub App. Needed for module import, lab import and branch
previews.

1. Instruqt, team `diagrid`: **Integrations** (sidebar) -> **Version control** *(docs, not verified)*.
2. Click **Add GitHub account** and pick the `diagrid-labs` organization on GitHub.
3. On the GitHub page choose **Only select repositories** and select
   `diagrid-labs/dapr-university-instruqt`. Click **Install** (or **Save** if the app is already
   installed).
4. Back in Instruqt, reload the Version control page.

**Expected:** `diagrid-labs` is listed with a connected state and `dapr-university-instruqt`
appears as an available repository when you reach the import screens in sections 7 and 9.
If the repository is missing, go to GitHub -> `diagrid-labs` -> Settings -> GitHub Apps ->
Instruqt -> Configure and add the repository.

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
2. Instruqt: **Building blocks** -> **Images** -> **Create image** *(docs, not verified)*.
   - Name: `dapr-sandbox`
   - Base image: `ubuntu:24.04` (System images), Version: Latest
   - Machine: Large, Disk: 60 GB
   - Click **Start building**.

   **Expected:** a build session opens with an Editor and a Terminal panel. The session lasts at
   most 2 hours and is reclaimed after 15 minutes idle.
3. Get `image.sh` into the session. Pick one:
   - Open `image.sh` locally, copy its contents, create a file in the session's Editor panel
     (for example `/root/image.sh`) and paste.
   - Or put the file somewhere fetchable (for example a secret gist: `gh gist create image.sh`)
     and in the session terminal run `curl -fsSL <raw-url> -o /root/image.sh`. The script
     contains no secrets. Note `image.sh` is generated, so the raw file of the repo branch does
     not contain it.
4. In the session terminal run it and watch for errors:

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
7. Take a Checkpoint if the UI offers one, then **Publish** the image *(docs, not verified)*.
   Name `dapr-sandbox`, tag `v1`.
8. Write down the full image reference exactly as shown after publishing, for example
   `diagrid/dapr-sandbox:v1`. You need it in section 3.

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

1. Instruqt: **Building blocks** -> **Modules** -> **Import module** *(docs, not verified)*.
2. Repository: `diagrid-labs/dapr-university-instruqt`. Module name: `dapr-sandbox`.
   Module directory: `modules/dapr-sandbox`. Leave **Publish to the community registry** off.
3. Open the imported module. If the editor is in edit mode, leave edit mode.
4. Click **Publish version** and enter `1.0.0` (strict `MAJOR.MINOR.PATCH`).

**Expected:** the module is listed as `diagrid/dapr-sandbox` with version `1.0.0`. A later
change to `modules/dapr-sandbox/main.hcl` on `main` does **not** change published `1.0.0`; new
content needs a new version cut by hand (see "Toolchain bump").

If the version you publish differs from `1.0.0`, change `version` in the `module "sandbox"`
block of `dapr-secrets/versions.hcl` to match, in a PR.

---

## 8. Secrets

None expected. The Docker Hub PAT (`DockerUSER`/`DockerPAT`) that the old track used is
intentionally **not** used any more: the daprio, redis, zipkin and vault images are pre-pulled
into the image, and a secret in a VM `environment` would be readable by learners. Do not create
team secrets for this lab (Building blocks -> Secrets *(docs, not verified)* stays untouched).

**Expected:** `grep -rn "DockerPAT\|DockerUSER" dapr-secrets/scripts dapr-secrets/*.hcl modules`
finds nothing. (Only the legacy `dapr-secrets/_setup/sandbox-setup.sh` still mentions them; the
2.0 lab does not use `_setup/`.)

---

## 9. Import the lab

1. Instruqt: **Labs** -> **Import lab** *(docs, not verified)*.
2. Repository `diagrid-labs/dapr-university-instruqt`, branch `main`, Root directory
   `dapr-secrets`.
3. Confirm the import.

**Warning:** a lab imported at a sub-directory root cannot be disconnected from the repo later.
Check the root directory spelling before you confirm.

**Expected:** a lab titled "Dapr Secrets - Read, Scope, and Swap Secret Stores" with chapter
"Dapr Secrets" and four pages (What is the Secrets API; The component and its parameters; Secret
scoping; Swap the provider). The module `diagrid/dapr-sandbox` 1.0.0 resolves with no error in
the lab editor. If it does not, the module was not published (section 7) or the version differs
from `version` in `dapr-secrets/versions.hcl`.

---

## 10. Preview and acceptance play-through

### Previewing a branch

Use this whenever you change the lab, before merging.

1. Push the branch (`git push`).
2. In the lab editor open the branch selector in the top bar and look for the branch under
   **Branches** *(docs, not verified)*. Pushes can take a minute to show up.
3. Select the branch and click **Play**.

**Expected:** the branch plays independently of the live version. If a branch of this
sub-directory lab is not listed, record that in `docs/instruqt-2-spike-checklist.md` (Item 9
finding) and play the lab from `main` after merge instead.

### Acceptance play-through

Play the lab three times (see Timing). In each play go through all four pages in one language
(.NET, Python or Java), so that all three languages are covered by the end. Copy this checklist
into your notes per run.

Layout reminder: instructions column, tabs **Editor**, **Dapr CLI** (terminal), **curl**
(terminal).

| Page | .NET | Python | Java |
| --- | --- | --- | --- |
| 1. What is the Secrets API: instructions render, language `<details>` open, `bash,run` buttons paste into the terminal, Demo1 runs with `dapr run -f .` and the curl call returns the secret | [ ] | [ ] | [ ] |
| 2. The component and its parameters: edit the component in the Editor, save, rerun, the single and bulk calls and `secretKeyRef` step work | [ ] | [ ] | [ ] |
| 3. Secret scoping: app A reads `orderdb-password`, app B is refused (403) after enabling `configFilePath`, app B still reads `payments-api-key`; task check goes green | [ ] | [ ] | [ ] |
| 4. Swap the provider: the app in Demo3-SwapProvider reads `orderdb-password` from Vault; task check goes green | [ ] | [ ] | [ ] |

Also tick once per run: the Editor opens `/root/ai-agent-tracks-instruqt/secrets`; `Skip` on
the task on pages 3 and 4 runs the solve script and the check then passes; no page asks for a
credential; `env | grep -i -E "pat|token|password"` in the terminal shows nothing sensitive.

**Deliberate failures (once per run, on pages 3 and 4).** A check failure shows only the static
`failure_message` of the failing condition, so confirm the hint matches the mistake:

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
   (`"initialized":true`).
5. If a run is over 1:30, list what was slow (image pull, `dapr init`, Vault seeding) and look
   for what can move into the image or be dropped. Hot starts are out of scope.

### Record the results

Write the outcome (date, three times, languages covered, failed boxes, deviations in the UI
paths above) on the `Finding:` lines of Items 3, 5, 9 and 10 in
`docs/instruqt-2-spike-checklist.md`. Item 10 (the 1:30 timing) is the gate for the embed.

---

## 11. `INSTRUQT_TOKEN` (optional)

Only needed if you want `instruqt lab test diagrid/dapr-secrets` to run from CI or locally. No
workflow in the repo uses it yet, so skip this unless you add such a job.

1. Create an API token for your Instruqt account (Instruqt -> your profile -> **API tokens**
   *(docs, not verified)*), or run `instruqt auth login` locally.
2. For CI: GitHub -> repo **Settings** -> **Secrets and variables** -> **Actions** -> **New
   repository secret**, Name `INSTRUQT_TOKEN`, Value the token.
3. Run locally (needs the lab to be imported, section 9):

   ```bash
   instruqt lab test diagrid/dapr-secrets
   instruqt lab test diagrid/dapr-secrets --ref feat/dapr-secrets-instruqt-2-lab
   ```

**Expected:** every task is checked (untouched must fail, then the solve script runs and the
check passes). `lab validate` and `lab format` need no token.

---

## 12. Embed the lab and replace the old embed

1. In the lab editor click the **Share** icon in the header -> **Embeds** -> **New embed**
   *(docs, not verified)*.
2. Fill in: Name `diagrid-university`, Lab version: the default branch (`main`), Access window
   24 hours, Plays per end user 1 (use Unlimited if learners need retries), Allowed sites: the
   Diagrid University site origin including the scheme and no path.
3. Save, then copy the iframe snippet from the Share tab.
4. On the Diagrid University site, replace the old Dapr Secrets (legacy track) embed code with
   the new snippet, preview the page and start the lab once.

**Expected:** the iframe starts the lab without sign-in; a play beyond the plays limit, or from a
site that is not in Allowed sites, is refused. Record the snippet shape and any `icp_` parameter
you will want later in `docs/instruqt-2-spike-checklist.md` (Item 11 finding).

Do this only after Item 10 (timing) and the play-through are done.

---

## Maintenance procedures

### Toolchain bump

For a new .NET, JDK, Node, Dapr CLI or prewarmed runtime version.

1. Edit the pin in `modules/dapr-sandbox/versions.hcl` (`dotnet_sdk_channel`, `java_version`,
   `node_major`, `dapr_cli_version` or `prewarm_dapr_runtime_version`).
2. Render the image script: `modules/dapr-sandbox/scripts/render-image-script.sh > image.sh`.
3. Rebuild the image as in section 2 (steps 2 to 8), publishing a new tag (for example `v2`).
4. Set `image_ref` in `modules/dapr-sandbox/versions.hcl` to the new reference.
5. Open a PR. `lab-validate` and `dapr-secrets-result` must pass; merge it.
6. Import/refresh the module and **Publish version** as the next number (for example `1.1.0`;
   section 7). The published `1.0.0` keeps the old image.
7. In `dapr-secrets/versions.hcl`, bump `version` in the `module "sandbox"` block to that number
   and merge by PR.
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
