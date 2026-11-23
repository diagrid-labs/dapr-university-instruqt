# Single source of truth for the dapr-workflow-101 lab pins. Keep each pin a plain
# `variable "<name>" { default = "<value>" }` block: tools/track-tester/ci/read_pin.py reads them.
# The sandbox toolchain pins live in modules/dapr-sandbox/versions.hcl.

variable "dapr_runtime_version" {
  description = "Dapr runtime the lab initialises (dapr init --runtime-version). Must equal prewarm_dapr_runtime_version in modules/dapr-sandbox/versions.hcl."
  default     = "1.19.2"
}

variable "tracks_src_ref" {
  description = "Commit of diagrid-labs/university-labs that the lab checks out after cloning."
  default     = "44ccac885472d6e11937d766555e8203bd0204b6"
}

# Shared sandbox module, published as diagrid/dapr-sandbox (source: ../modules/dapr-sandbox).
# `instruqt lab validate` cannot resolve registry sources, so validate through
# tools/track-tester/ci/validate-lab.sh, which swaps in a local copy of the module.
# The module's shared setup (sandbox-setup.sh in the image: Docker/DNS wait, demo clone, Editor,
# Dev Dashboard, dapr init) runs first. The lab script is lab-setup.sh (starts the demo pre-build
# in the background); the module inlines it into the VM startup script because the lab's files
# are not on the VM. The demos need no service of their own: workflow state lives in the Redis
# container that `dapr init` starts.
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
    editor_folder        = "workflow"
    lab_startup_script   = file("scripts/lab-setup.sh")
  }
}
