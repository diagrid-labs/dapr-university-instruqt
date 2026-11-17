# dapr-sandbox module

Shared Instruqt 2.0 module that gives a lab one sandbox VM with the Dapr toolchain preinstalled.
Published as `diagrid/dapr-sandbox`.

## What it provides

A `vm` built from a custom image containing Docker Engine, .NET SDK, JDK + Maven, Python 3 + uv
(on `/usr/local/bin`), Node.js + npm, the Dapr CLI, code-server (VS Code in the browser) and
Diagrid's Dapr Dev Dashboard, with package caches and container images pre-pulled. code-server and
the Dev Dashboard are only installed; the lab setup starts them for the Editor and Dev Dashboard
tabs. Versions are pinned in `versions.hcl`. The module runs a shared setup first
(`sandbox-setup.sh`, below); the lab adds its own steps through `lab_startup_script`.

## Inputs

| Variable | Default | Purpose |
| --- | --- | --- |
| `cpu` | `4` | vCPUs |
| `memory` | `8192` | memory in MB |
| `dapr_runtime_version` | `""` | Dapr runtime version for `dapr init` (the lab's pin); setup fails when empty |
| `demo_repo_url` | the `diagrid-labs/ai-agent-tracks-instruqt` URL | demo repo cloned to `/root/ai-agent-tracks-instruqt` |
| `demo_repo_ref` | `""` | commit SHA (or ref) to check out; setup fails when empty |
| `editor_folder` | `""` | folder in the clone the Editor tab opens, e.g. `pubsub`; setup fails when empty |
| `lab_startup_script` | `""` | script content run on VM boot, usually `file("scripts/setup.sh")` from the lab |
| `lab_environment` | `{}` | env vars for that script (readable by learners, never credentials) |

## Shared setup (`sandbox-setup.sh`)

Every lab needs the same boot steps, so the module does them before the lab script, in this order:
`HOME=/root`, logging (`/var/log/lab-setup.log`), wait for Docker, the DNS workaround (public
resolvers when the VM's resolver does not answer; overridable with `LAB_RESOLV_CONF` and
`LAB_DOCKER_DAEMON_JSON` for tests), an HTTPS probe of github.com, the clone of `demo_repo_url`
at `demo_repo_ref` into `/root/ai-agent-tracks-instruqt` (only when absent), code-server on port
8888 opened on `/root/ai-agent-tracks-instruqt/<editor_folder>`, the Dev Dashboard on port 9090,
and `dapr init --runtime-version <dapr_runtime_version>` (skipped when the Dapr containers already
run). The script lives in the image at `/usr/local/lib/dapr-sandbox/sandbox-setup.sh` and the
startup script exports the four inputs as `DAPR_RUNTIME_VERSION`, `DEMO_REPO_URL`,
`DEMO_REPO_REF` and `EDITOR_FOLDER`, then sources it. After it, these are available to the lab
script: the functions `log`, `die`, `bounded` and `wait_for_docker`, and the variables `HOME`,
`TRACKS_SRC_DIR` and `LAB_SETUP_LOG`.

The file is shipped in the image (`render-image-script.sh` embeds it), so **a change to
`scripts/sandbox-setup.sh` needs an image rebuild and a new module version**.

## Readiness marker

The module owns the readiness marker. Its startup script runs the shared setup and then the lab
script in a subshell (`set -euo pipefail`), then creates `/var/lib/lab-setup/ready`. Instruqt keeps the sandbox in
"Creating sandbox" until that startup script has finished, so the lab is only playable once the
lab script succeeded; the marker is there for a manual check (`ls /var/lib/lab-setup/ready`).
There is no VM health check: an exec health check on the marker timed out on a VM even after the
script had written it (module 1.0.0), so 1.0.1 removed it. Consequences for lab scripts:

- Do not create the marker yourself.
- A failing command (with `set -e`) fails the whole startup, so the sandbox never becomes ready.
- An early `exit 0` only leaves the subshell, so the marker is still written.
- The lab script runs inline, so it must background any long work itself if the learner should
  not wait for it.
- The embedded lab script inherits `set -euo pipefail` from the module's startup script, so write
  it for strict mode (guard `grep` and other commands that may exit non-zero).
- A background job must redirect stdout and stderr, for example `nohup cmd >log 2>&1 &`. Otherwise
  the job keeps the startup script's pipe open and the startup waits on it until the job ends.
- With the default empty script the module still becomes ready.

The toolchain pins in `versions.hcl` (`image_ref`, `dotnet_sdk_channel`, `java_version`,
`node_major`, `dapr_cli_version`, `code_server_version`, `dev_dashboard_version`,
`prewarm_dapr_runtime_version`) are declared as `variable`
blocks only so `read_pin.py` can read them. Labs must not override them: the image is prebuilt,
so overriding a toolchain pin changes nothing (`image_ref` is the one exception, it picks the
image). Only `cpu`, `memory`, `dapr_runtime_version`, `demo_repo_url`, `demo_repo_ref`, `editor_folder`,
`lab_startup_script` and `lab_environment` are inputs.

## Output

`vm`: use `module.<name>.output.vm` as the target of terminals, editors and tasks.

## Image build

`versions.hcl` is the single source for the toolchain. To build the image:

1. In the Instruqt UI, start an Image Builder session from base `ubuntu:24.04`.
2. Run `modules/dapr-sandbox/scripts/render-image-script.sh > image.sh` locally and paste its
   output into the session terminal. The output is self-contained and also installs
   `sandbox-setup.sh` to `/usr/local/lib/dapr-sandbox/`.
3. Publish the image, then set `image_ref` in `versions.hcl` to `diagrid/<image-name>:<tag>`.

The scripts install software and pull container images only. They never run `dapr init` or start
a container, because the Image Builder saves the state of running services into the image.

`prewarm_dapr_runtime_version` decides which `daprio/dapr` tag is pre-pulled. It must match the
lab's `dapr_runtime_version` (in the lab's `versions.hcl`) for the pre-pull to help.

## Bumping the toolchain

Edit `versions.hcl`, rebuild the image per the steps above, then publish a new module version and
bump the version the labs reference.
