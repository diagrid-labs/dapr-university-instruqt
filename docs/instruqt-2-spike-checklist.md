# Instruqt 2.0 spike checklist and schema facts

Instruqt CLI version: 2442-5df184f

Date: 2026-11-10. Spec: `docs/superpowers/specs/2026-11-10-dapr-secrets-instruqt-2-lab-design.md` (section "Phase 0: spike").

This file has two parts:

1. **Schema facts**: what `instruqt lab validate` actually accepted or rejected with CLI `2442-5df184f`, found by editing a scratch lab. Tasks that write HCL follow this part. Statements marked *(docs only)* come from https://docs.labs.instruqt.com/ and were not exercised by `validate`.
2. **Spike checklist**: Phase 0 items 2-11, run by the track owner on Instruqt. Record each result on its `Finding:` line.

Phase 0 item 1 (install the CLI, scaffold, confirm `validate`/`fmt` work without auth) was done by the builder; see "CLI facts" below.

---

## Part 1: Schema facts

### CLI facts

- The CLI has these lab commands: `instruqt lab init | validate | format | test | logs`. The formatter is `format` (alias `fmt`), not only `fmt`.
- `instruqt lab init --template skeleton --dir <empty-or-absent-dir>` scaffolds non-interactively. The `skeleton` scaffold validates untouched.
- Scaffold layout: `main.hcl`, `layouts.hcl`, `README.md`, and empty convention folders `assets/`, `files/`, `instructions/`, `notes/`, `scripts/` (each holds only a README). The folder names are convention; paths are whatever the HCL says.
- `instruqt lab validate [path]` and `instruqt lab format [file | path]` default to the current directory.
- **No auth needed** for `validate` and `format`: both ran with no Instruqt config file present (no `instruqt auth login`), so they can run in CI without a token.
- `instruqt lab validate` on a directory that has no `lab` resource (for example the module directory) passes, so **`validate` accepts a module directory**:

  ```
  $ instruqt lab validate modules/dapr-sandbox
  ==> Validating lab...
      [SUCCESS] Lab is valid
  ```
- `instruqt lab format` rewrites files in place and **always exits 0**. It prints `Formatting <file>` for each file it changed. A CI "fail if it changes anything" check must therefore run `format` and then `git diff --exit-code` (or compare the `Formatting` lines); the exit code alone says nothing.
- `instruqt lab test <team>/<lab> [--ref <branch|tag>] [--scope content|sandbox] [--workspace <ws>]` runs a deployed lab through tasks (check untouched, then solve) and quizzes. It needs auth and a deployed lab (not exercised here).
- `validate` does **not** verify that a `file("...")` target exists. A `startup_script = file("scripts/missing.sh")` and a `file("../../scripts/check.sh")` that leaves the module both validated. A missing file may only fail on Instruqt, so keep a CI step that checks script paths exist.
- `validate` does check references: `module.sandbox.output.nope` (an undeclared output) is rejected with `module "module.sandbox" does not expose output "nope"`.

### Answers to the five questions in the task brief

**1. Does a lab accept `variable` blocks with `default`? Yes.**

```hcl
variable "dapr_runtime_version" {
  default     = "1.19.1"
  description = "Dapr runtime version"
}
```

Referenced as `variable.dapr_runtime_version` (validated inside a VM `environment` map). Variables are typed by value (string, number, bool, list, object); there is no required `type` argument. `description` and `default` are the documented fields. A lab can only have its variables overridden at launch by embed URL parameters starting `icp_` *(docs only)*; this is not needed for our pins.

Limit found: a module call whose `version` is set from a variable (`version = variable.sandbox_version`) could not be validated, because registry modules do not resolve in the CLI (see question 3). Whether `version` accepts a variable on Instruqt itself is untested. Assume `version` must be a literal string.

**2. Does `startup_script` accept `file("...")`? Yes.**

```hcl
resource "vm" "sandbox" {
  image {
    name = "ubuntu:24.04"
  }

  resources {
    cpu    = variable.cpu
    memory = variable.memory
  }

  startup_script = file("scripts/install-tools.sh")
}
```

- The path is relative to the HCL file that contains the call (docs), and the file is read verbatim. Scripts are not templates; use `template_file(path, vars)` (Handlebars) if values must be substituted, or pass values through `environment`.
- `resources { cpu memory }` is **required** on a `vm`. Omitting it fails with `resources are required (resource: resource.vm.extra, field: resources)`. `cpu` is whole cores, `memory` is MB.
- `environment = { NAME = variable.x }` validated. Values in a VM `environment` are readable by learners (docs). This matches the spec's no-credentials rule.
- A VM `health_check { timeout = "60s" exec { script = "scripts/check.sh" } }` validated. The docs say exec health checks are run by the in-VM agent.

**3. Does `module` accept a local source outside the lab root (`../modules/dapr-sandbox`)? No.**

```
[ERROR] module "sandbox": module source "../modules/dapr-sandbox" resolves to ../modules/dapr-sandbox, outside .
Lab is not valid
```

A local source must resolve **inside** the content that declares it (`./a/../b` is fine, `../../elsewhere` is refused). With the lab rooted at `dapr-secrets/`, a repo-level `modules/dapr-sandbox` is therefore not reachable as a local module. What did validate:

- Local module **inside** the lab root works:

  ```hcl
  module "sandbox" {
    source = "./modules/dapr-sandbox"

    variables = {
      cpu    = 4
      memory = 8192
    }
  }
  ```

  Here the module directory sits at `<lab root>/modules/dapr-sandbox`. This option is unversioned and not shareable between labs.
- A **registry** source is syntactically accepted but **cannot be resolved by the CLI**:

  ```hcl
  module "sandbox" {
    source  = "diagrid/dapr-sandbox"
    version = "1.0.0"
  }
  ```

  ```
  [ERROR] module "sandbox": source "diagrid/dapr-sandbox" names a published module, which cannot be resolved here
  ```

  Docs confirm: "`instruqt lab validate` resolves local modules, but it cannot resolve registry addresses – the CLI has no registry fetcher." So a lab that consumes `diagrid/dapr-sandbox` fails `instruqt lab validate` in CI, with or without auth. CI for the lab would need a workaround (for example validate against a temporary copy that swaps in a local source), or validate the lab in the Instruqt editor only.
- Module `source` forms (docs): `./relative` or `../relative` (must land inside the content), or `team-slug/module-slug` with a strict `MAJOR.MINOR.PATCH` `version` (exact, or a constraint such as `^1.4.0`; no `v`, no prerelease). No git URLs.
- A published module is its own content and cannot read files above its own root (docs), so `file("scripts/install-tools.sh")` inside the module must stay inside the module directory.

**4. What is the editor tab resource type called? `editor`.**

An editor is a resource with named `workspace` blocks; a layout tab then points at it. It validated with a module-output VM as the target:

```hcl
resource "editor" "code" {
  workspace "secrets" {
    target    = module.sandbox.output.vm
    directory = "/root/ai-agent-tracks-instruqt/secrets"
  }
}
```

(`target` is optional per workspace; without it the workspace is local to the lab content. Docs show only container targets for the editor; a VM target passed `validate`, but whether the editor can browse a VM's filesystem is **spike item 7**.)

Tab in a layout:

```hcl
resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  column {
    width = "60"

    tab "editor" {
      target = resource.editor.code
      title  = "Editor"
      active = true
    }

    tab "cli" {
      target = resource.terminal.cli
      title  = "Dapr CLI"
    }
  }
}
```

**5. Does `lab validate` accept a module directory? Yes** (see CLI facts). It validates the module's HCL as a standalone config.

### Extra schema facts later tasks need

**Module input variables and outputs: `variable` and `output` blocks, yes.** Validated file layout inside `modules/dapr-sandbox/`:

```hcl
# variables.hcl
variable "cpu" {
  description = "Number of vCPUs for the sandbox VM"
  default     = 4
}

variable "memory" {
  description = "Memory for the sandbox VM in MB"
  default     = 8192
}
```

```hcl
# outputs.hcl
output "vm" {
  description = "The sandbox VM"
  value       = resource.vm.sandbox
}
```

The lab then uses `module.sandbox.output.vm` as a `target` for a `terminal`, `editor` workspace, and `task` `config { target = ... }`; all validated. The reference form is `module.<block>.output.<name>`; the form `module.<block>.<name>` passes on old CLIs but does not work at runtime (docs). A key in the module call's `variables = { ... }` that the module does not declare is **not** an error and does nothing (`validate` accepted it). The `.hcl` file split is free-form; all `*.hcl` files in a directory are one config.

**Terminal working directory: yes.**

```hcl
resource "terminal" "cli" {
  target            = module.sandbox.output.vm
  shell             = "/bin/bash"
  working_directory = "/root/ai-agent-tracks-instruqt/secrets"
}
```

`terminal` also accepts `user`, `group` and `command`. With a VM target, shell, user, group and directory are interpreted by the VM's OS (docs), so they must exist there. A `~` in `working_directory` is not documented; use an absolute path. A separate curl terminal is a second `resource "terminal"`. Editor workspaces take a `directory` per workspace instead.

**Idle timeout and extra time: yes, in `settings`.**

```hcl
resource "lab" "main" {
  title       = "Spike lab"
  description = "Schema spike"

  settings {
    timelimit {
      duration   = "30m"
      extend     = "10m"
      show_timer = true
    }

    idle {
      enabled      = true
      timeout      = "10m"
      show_warning = true
    }
  }

  layout = resource.layout.main

  content {
    chapter "__default" {
      title = "Default"

      page "intro" {
        reference = resource.page.intro
      }
    }
  }
}
```

- `timelimit.duration` is the session limit and is mandatory in practice: a lab without it validates but sessions are refused (docs).
- `timelimit.extend` is the extra time offered; `idle.timeout` the idle timeout. All validated.
- The chapter label `__default` hides the chapter level, so the four pages show as a flat list. Use a named chapter instead if the spec's "one chapter" should be visible.

**Task condition with `solve`: a `solve` block inside the condition, next to `check`.** A `solve` script runs when the learner skips the task (docs). Validated:

```hcl
resource "task" "check" {
  description = "Check"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root"
  }

  condition "one" {
    description = "One"

    check {
      script          = "scripts/check.sh"
      failure_message = "cause A"
    }

    check {
      script          = "scripts/check.sh"
      failure_message = "cause B"
    }

    solve {
      script = "scripts/solve.sh"
    }
  }
}
```

- Several `check` blocks in one condition validated. Per docs, every check in a condition runs, and the learner sees the `failure_message` of each one that failed. `failure_message` is a fixed string; a check script's output is captured for debugging and is **not shown to the learner** (docs). This answers spike item 8's first half from docs; item 8 still asks the owner to confirm in the player.
- Task also supports `setup` and `cleanup` script blocks inside a condition (docs only). `setup` runs when the condition becomes active (a candidate for the per-challenge `setup.sh` hook; confirm in item 8). Default script timeout is 30s; raise it with `config { timeout = "60s" }` on the task, condition or script.
- A task `config.target` may be a VM (validated; the docs say scripts then run through the guest agent).

**Page lists activities: an `activities` map of ID to resource, and the markdown embeds by ID.** Validated:

```hcl
resource "page" "intro" {
  title = "Intro"
  file  = "1-intro/assignment.md"

  activities = {
    check = resource.task.check
  }
}
```

```markdown
<instruqt-task id="check"></instruqt-task>
```

`file` is relative to the lab root and may point at the existing `N-slug/assignment.md`. A page also takes a `variables = { ... }` map for Handlebars `{{name}}` substitution (docs).

**`exec` cannot target a VM in practice.** `resource "exec" { target = module.sandbox.output.vm ... }` passed `validate`, but the docs say exec runs on the sandbox host or in containers only, and name the VM `startup_script` or a task targeting the VM as the way to run scripts on a VM. Do not use `exec` for the VM. Sandbox creation waits for every exec script to exit (default 300s timeout) (docs).

**Module publishing (docs only):** there is **no CLI or API publish command**. A module is created in the UI (Building blocks, Modules, Create module) or imported from a GitHub repository directory (Import module, choose the "Module directory"; reads the repo's default branch). A version is cut with **Publish version** in the module editor from committed branch content, as a strict semver number; a version is not a git tag. This answers part of spike item 4 from docs.

**Image builder (docs only):** a custom VM image is built by hand in the UI (Building blocks, Images) from an Instruqt base image (for example `ubuntu:24.04`), in a build session (2 hour max, 15 minute idle reclaim). The lab references it as `team-slug/image-name` in `image { name = "..." }`, with a version tag. The docs say to install software and pull container images in the session but **not initialize or start** services there (publish stops the VM without shutting services down, and state from a running Docker daemon or Vault is saved into the image). Disk is 20-500 GB (40 default) and carries into every VM booted from the image; the root filesystem otherwise never grows.

**Branches and previews (docs only):** each branch of a lab can be launched and previewed independently of the live version. Pushes to the connected branch deploy. An imported lab at a sub-directory root (our `dapr-secrets`) cannot be disconnected later.

**Markdown (docs only):** the page editor's Insert menu offers Note, Tip, Important, Warning and Caution alert blocks, `<instruqt-completion>`, feedback, and `<instruqt-code-group>`. The docs do not say whether GitHub-style `> [!NOTE]` or `<details>` render; that is spike item 6.

**Embeds (docs only):** Share (header icon), Embeds, New embed gives an iframe snippet with a play token, an access window, plays per user, and an allowed-sites list. URL parameters starting `icp_` set lab variables.

---

## Part 2: Spike checklist (Phase 0 items 2-11)

Item 1 is done (see CLI facts above). Do the rest in order; items 2, 3, 4, 5 and 10 gate the rest. Replace the empty `Finding:` line with a one-line result (and a date) as you go.

Where a step needs a throwaway lab, create it in the Instruqt UI (Labs, Create lab) or push a scratch branch; delete it afterwards. Test sandbox VMs by launching the lab and using its terminal tab.

### Item 2: Docker Engine inside a 2.0 VM; `dapr init` and Vault work

- **How to test:**
  1. Make a scratch lab with one `vm` (`ubuntu:24.04`, `resources { cpu = 4 memory = 8192 }`) and one `terminal` tab targeting it (start from `instruqt lab init --template skeleton`, add the two resources, `instruqt lab validate`, push or import).
  2. Play it. In the terminal run:

     ```bash
     whoami
     id
     curl -fsSL https://get.docker.com | sh
     docker run --rm hello-world
     curl -fsSL https://raw.githubusercontent.com/dapr/cli/master/install/install.sh | bash -s 1.19.1
     dapr init --runtime-version 1.19.1
     docker ps
     docker run -d --name vault -p 8200:8200 -e VAULT_DEV_ROOT_TOKEN_ID=root hashicorp/vault:1.20
     curl -s http://localhost:8200/v1/sys/health
     ```
- **Expected result:** Docker installs and `hello-world` runs; `dapr init` finishes with placement, scheduler, Redis and Zipkin containers listed by `docker ps`; the Vault container answers on 8200 with `"initialized":true`. Note the wall-clock time of each step, what `whoami` and `id` print (is the terminal user root, or in the `docker` group?) and any need for `sudo`.
- **Finding:**

### Item 3: Image Builder can build the image, and Docker runs during the build

- **How to test:**
  1. In Instruqt: Building blocks, Images, Create image. Base image `ubuntu:24.04` (System images), Version Latest, Machine Large, Disk 60 GB. Click Start building.
  2. In the builder Terminal, get the scripts onto the VM (type them in the Editor panel, or `curl` them from a raw GitHub URL of this repo's branch), then run `install-tools.sh` and `prewarm.sh` (draft versions are fine for the spike; a stub that installs Docker, .NET 10 SDK, JDK 17 + Maven, Python 3.12 + uv, Node LTS, Dapr CLI is enough).
  3. Run `docker info` and `docker pull hashicorp/vault:1.20` in the same session to check the daemon runs.
  4. Take a Checkpoint, then Publish as a new image named `dapr-sandbox-spike`, tag `v1`. Note the image size.
  5. Create a lab VM with `image { name = "diagrid/dapr-sandbox-spike:v1" }`, play it, and run `docker images` and `dotnet --version`.
- **Expected result:** the build finishes inside the 2 hour session; `docker info` works; pulled images (`hashicorp/vault:1.20`, `daprio/daprd`, `redis`, `openzipkin/zipkin`) are still listed by `docker images` in a lab VM booted from the published image. If the daemon cannot run in the build, record the exact error. Per the docs, do not run `dapr init` or leave a Vault container running in the build; only pull images.
- **Finding:**

### Item 4: Modules can be published from git/CLI; a lab can use a local module outside its root

- **How to test:**
  1. Local module outside the root: already answered by `validate` (rejected, see Schema facts question 3). Optionally re-confirm in the UI by importing a lab whose `module` source is `../modules/dapr-sandbox` and noting the editor error.
  2. Registry publish from git: in Instruqt, Building blocks, Modules, Import module. Pick this repo (the GitHub App must have access, see Item 9 and the runbook), Module name `dapr-sandbox`, Module directory `modules/dapr-sandbox`, leave "Publish to the community registry" off. Then open the module, leave edit mode, click Publish version and enter `1.0.0`.
  3. In a scratch lab (UI editor), add `module "sandbox" { source = "diagrid/dapr-sandbox" version = "1.0.0" }` and confirm it resolves and a VM from the module starts.
  4. Check whether any CLI or API command publishes a module version (`instruqt --help`, `instruqt lab --help`, and the web docs). From the CLI help in `2442-5df184f`, there is none.
- **Expected result:** import from the `modules/dapr-sandbox` directory works; a version is published only through the UI; the lab resolves `diagrid/dapr-sandbox` at `1.0.0`. Record what happens when `modules/dapr-sandbox/main.hcl` changes on the default branch: the published version must not change; a new version must be cut by hand.
- **Finding:**

### Item 5: A lab-level setup script runs on a VM before the sandbox reports ready

- **How to test:**
  1. In the scratch lab, give the VM `startup_script = file("scripts/slow-setup.sh")` where the script runs `sleep 45 && touch /tmp/setup-done` and logs timestamps.
  2. Time "Start" until the lab's first page is usable and check, in the terminal, whether `/tmp/setup-done` already exists when the page opens.
  3. Repeat with the VM `health_check { timeout = "120s" exec { script = "scripts/ready.sh" } }` where `ready.sh` exits 0 only if `/tmp/setup-done` exists. Check whether the sandbox now waits for it.
  4. Repeat with a task whose `condition` has a `setup` script and `config { target = <vm> }` placed on the first page; check whether the page waits for the task.
  5. Try passing the lab pins in with `environment = { DAPR_RUNTIME_VERSION = variable.dapr_runtime_version }` and confirm the script sees them.
  6. From inside the startup script, log `echo $HOME; id` and `systemctl is-active docker` at the very start, and `docker info` right after. Expect `/root`, uid 0 and `active`; if Docker is not yet active at script start, note how long it takes (lab-setup.sh waits up to 60 seconds).
  7. Start a detached background job from the startup script (`nohup ... &`, as the Demo2 pre-build does) that appends to `/var/log/lab-prebuild.log`, then check after the script has exited and the sandbox is ready whether the log keeps growing and the builds complete, or whether the job is killed when the startup script exits.
- **Expected result:** at least one of `startup_script`, VM `health_check`, or a task `setup` script blocks readiness until it finishes. Record which blocks, which times out and how (the exec docs give a 300s default for exec; VM scripts are undocumented), and whether the learner terminal can read the script's environment variables (they can, so no credentials).
- **Finding:**

### Item 6: `> [!NOTE]` alerts and `<details>` sections render

- **How to test:** in the scratch lab, make a page file with:

  ````markdown
  > [!IMPORTANT]
  > Important alert.

  > [!NOTE]
  > Note alert.

  <details>
  <summary>.NET</summary>

  Hidden .NET text and a block:

  ```bash,run
  echo hello
  ```

  </details>

  <instruqt-code-group>

  ```bash title="one"
  echo one
  ```

  ```bash title="two"
  echo two
  ```

  </instruqt-code-group>
  ````

  Also use the page editor's Insert menu, Alerts, Note and copy the markdown it produces. Play the lab and open the page.
- **Expected result:** the alerts render as styled callouts (or you learn the 2.0 syntax the editor inserts); the `<details>` section collapses and the `bash,run` button works inside it. If either fails, record the 2.0 equivalent and the effect on `docsync/check_doc_sync.py` (it keys off `<summary>` language markers).
- **Finding:**

### Item 7: A code-editor tab type exists and works on a VM

- **How to test:** in the scratch lab add

  ```hcl
  resource "editor" "code" {
    workspace "home" {
      target    = resource.vm.sandbox
      directory = "/root"
    }
  }
  ```

  plus a layout tab pointing at it (see Schema facts question 4). Play the lab. Open a file, edit it, save, and read it back from the terminal tab.
- **Expected result:** the `editor` tab opens a file tree of the VM directory and saves edits to the VM's disk. The type is `editor`; the open question is whether it can target a VM (docs only show containers). If it cannot, record the closest alternative (a terminal with `vim`/`nano`, a `virtualdesktop` tab with VS Code, or a `service` tab pointing at `code-server` on the VM).
- **Finding:**

### Item 8: Task output visibility and setup hooks

- **How to test:**
  1. In the scratch lab define a task with two `check` blocks, each with its own `failure_message`, where the scripts print different text to stdout and stderr and exit 1. Embed it with `<instruqt-task id="...">`. Play, click Check without doing the work, and note exactly what the learner sees.
  2. Add a `setup` script to a condition that writes `/tmp/setup-ran`. Check whether it runs when the page opens, when the learner clicks into the task, or at sandbox start.
  3. Click Skip on the task; check the `solve` script runs.
- **Expected result:** per the docs, only the static `failure_message` text of each failing check is shown (so split each cause into its own `check`); check script output is not shown; `setup` runs when the condition becomes active; skip runs `solve`. Record the real behavior, including whether a task on page 3 can run `setup` when the learner opens page 3 without having done pages 1-2.
- **Finding:**

### Item 9: Pushed non-default branches appear as playable preview labs

- **How to test:**
  1. Complete the GitHub App setup (Integrations, Version control, Add GitHub account) for `diagrid-labs/dapr-university-instruqt` and import a scratch lab: Labs, Import lab, this repo, branch `main` (or a scratch branch), Root directory the lab folder.
  2. Push a new branch with a trivial title change. In the lab editor open the branch selector (top bar) and look for it under Branches.
  3. Select the branch and click Play. Also try the same with an embed's Lab version field.
- **Expected result:** the pushed branch appears in the branch selector and can be played and previewed independently of the live version. Record the delay between push and appearing, and whether a branch of a lab imported at a sub-directory root (not `/`) is listed.
- **Finding:**

### Item 10: A launch with the custom image plus lab setup finishes within 1:30

- **How to test:**
  1. Use the image from Item 3 and the lab setup script (clone the demo repo, `dapr init --runtime-version <pin>`, write `secrets.json`, start and seed Vault, pre-build Demo1 in all three languages), wired as decided in Item 5.
  2. Use a stopwatch. Start it when you click Start on the lab's start screen. Stop it when the first page is usable (instructions shown and the first terminal accepts a command). Do **three runs**, each as a fresh session, and note each time. Do at least one run after waiting 10 minutes since the last (a cold start).
  3. For each run, also record the sandbox-ready time and the lab-setup time separately if the player shows them (the session log, `instruqt lab logs`, or the timestamps your script writes to `/tmp/setup.log`).
- **Expected result:** all three runs are at or under 1 minute 30 seconds. If not, list what is slow (image pull, `dapr init`, Vault seeding, Demo1 pre-build) and what can move into the image (cache pre-warm, pre-pulled container images) or be dropped. Hot starts are out of scope.
- **Finding:**

### Item 11: How a 2.0 lab is embedded on an external site

- **How to test:** in the lab editor click the Share icon in the header, then Embeds, then New embed. Set Name `diagrid-university`, Lab version to the default branch, Access window 24 hours, Plays per end user 1 (or Unlimited if needed), Allowed sites to the Diagrid University site origin (scheme included, no path). Copy the iframe snippet from the Share tab and paste it into a test page on an allowed origin (or any page if Allowed sites is empty). Compare with the current embed code of a legacy track on the site.
- **Expected result:** the iframe starts the lab with no sign-in; users beyond the plays limit or on a disallowed origin are refused. Record the snippet shape and whether it replaces the legacy track embed one-to-one, plus any `icp_` parameter you want to pass later (for the HubSpot gating follow-up).
- **Finding:**
