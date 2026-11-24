# Single source of truth for the dapr-workflow-aspire lab pins. Keep each pin a plain
# `variable "<name>" { default = "<value>" }` block: tools/track-tester/ci/read_pin.py reads them.
# The sandbox toolchain pins live in modules/dapr-sandbox/versions.hcl.

variable "dapr_runtime_version" {
  description = "Dapr runtime the lab initialises (dapr init --runtime-version). Must equal prewarm_dapr_runtime_version in modules/dapr-sandbox/versions.hcl."
  default     = "1.19.2"
}

# The merge commit of diagrid-labs/university-labs PR #17, which adds the workflow-aspire/ workspace
# folder (a README and a .gitignore; the learner creates the solution there).
variable "tracks_src_ref" {
  description = "Commit of diagrid-labs/university-labs that the lab checks out after cloning."
  default     = "2fa0659512acb9ad9202e8d48ee949034d2e6b32"
}

# The pages repeat this version (`aspire new --version`, the `#:package` lines of apphost.cs); the
# suites fail when they differ. lab-setup.sh gets it as $LAB_ASPIRE_CLI_VERSION through
# lab_environment below, and CI reads it with read_pin.py. Never name it ASPIRE_CLI_VERSION in an
# environment: the Aspire CLI reads that variable as an identity override and then prints "Aspire
# CLI is emulating identity ..." on every command.
variable "aspire_cli_version" {
  description = "Aspire CLI the lab installs, and the Aspire version the pages create the solution with."
  default     = "17.0.0"
}

# Shared sandbox module, published as diagrid/dapr-sandbox (source: ../modules/dapr-sandbox).
# `instruqt lab validate` cannot resolve registry sources, so validate through
# tools/track-tester/ci/validate-lab.sh, which swaps in a local copy of the module.
# The module's shared setup (sandbox-setup.sh in the image: Docker/DNS wait, demo clone, Editor,
# Dev Dashboard, dapr init) runs first. The lab script is lab-setup.sh (stops the module's Dev
# Dashboard, installs the Aspire CLI, starts the warm-up in the background); the module inlines it
# into the VM startup script because the lab's files are not on the VM. lab_environment becomes the
# VM environment, which the startup script (and so lab-setup.sh) sees; learners can read it too, so
# it only ever holds versions. The workflow state lives in the Redis container that `dapr init`
# starts.
# 3.2.0 pre-pulls Dapr runtime 1.19.2 and must be published in Instruqt before this merges.
# Publish the module version in Instruqt (Building blocks > Modules > Publish version) BEFORE
# merging a change to `version` here. Every push syncs the lab and resolves this exact version; a
# push that pins a not-yet-published version leaves the lab on "failed to read hcl files: ...
# version X of diagrid/dapr-sandbox is not published: not found" until the next push.
module "sandbox" {
  source  = "diagrid/dapr-sandbox"
  version = "3.2.0"

  variables = {
    dapr_runtime_version = variable.dapr_runtime_version
    demo_repo_ref        = variable.tracks_src_ref
    editor_folder        = "workflow-aspire"
    lab_startup_script   = file("scripts/lab-setup.sh")
    lab_environment      = { LAB_ASPIRE_CLI_VERSION = variable.aspire_cli_version }
  }
}
