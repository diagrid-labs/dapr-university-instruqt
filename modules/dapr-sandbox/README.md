# dapr-sandbox module

Shared Instruqt 2.0 module that gives a lab one sandbox VM with the Dapr toolchain preinstalled.
Published as `diagrid/dapr-sandbox`.

## What it provides

A `vm` built from a custom image containing Docker Engine, .NET SDK, JDK + Maven, Python 3 + uv
(on `/usr/local/bin`), Node.js + npm and the Dapr CLI, with package caches and container images
pre-pulled. Versions are pinned in `versions.hcl`. The lab brings its own setup through
`lab_startup_script`.

## Inputs

| Variable | Default | Purpose |
| --- | --- | --- |
| `cpu` | `4` | vCPUs |
| `memory` | `8192` | memory in MB |
| `lab_startup_script` | `""` | script content run on VM boot, usually `file("scripts/setup.sh")` from the lab |
| `lab_environment` | `{}` | env vars for that script (readable by learners, never credentials) |

The VM health check passes once `/var/lib/lab-setup/ready` exists, so the lab startup script must
create that file as its last step. Otherwise the sandbox never becomes ready.

## Output

`vm`: use `module.<name>.output.vm` as the target of terminals, editors and tasks.

## Image build

`versions.hcl` is the single source for the toolchain. To build the image:

1. In the Instruqt UI, start an Image Builder session from base `ubuntu:24.04`.
2. Run `modules/dapr-sandbox/scripts/render-image-script.sh > image.sh` locally and paste its
   output into the session terminal. The output is self-contained.
3. Publish the image, then set `image_ref` in `versions.hcl` to `diagrid/<image-name>:<tag>`.

The scripts install software and pull container images only. They never run `dapr init` or start
a container, because the Image Builder saves the state of running services into the image.

`prewarm_dapr_runtime_version` decides which `daprio/dapr` tag is pre-pulled. It must match the
lab's `dapr_runtime_version` (in the lab's `versions.hcl`) for the pre-pull to help.

## Bumping the toolchain

Edit `versions.hcl`, rebuild the image per the steps above, then publish a new module version and
bump the version the labs reference.
