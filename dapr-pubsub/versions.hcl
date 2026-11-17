# Single source of truth for the dapr-pubsub lab pins. Keep each pin a plain
# `variable "<name>" { default = "<value>" }` block: tools/track-tester/ci/read_pin.py reads them.
# The sandbox toolchain pins live in modules/dapr-sandbox/versions.hcl.

variable "dapr_runtime_version" {
  description = "Dapr runtime the lab initialises (dapr init --runtime-version). Must equal prewarm_dapr_runtime_version in modules/dapr-sandbox/versions.hcl."
  default     = "1.19.1"
}

variable "tracks_src_ref" {
  description = "Commit of diagrid-labs/ai-agent-tracks-instruqt that the lab checks out after cloning."
  default     = "37fccac6583f4d5b1854002a234b5d25e4f3f9e8"
}

# Shared sandbox module, published as diagrid/dapr-sandbox (source: ../modules/dapr-sandbox).
# `instruqt lab validate` cannot resolve registry sources, so validate through
# tools/track-tester/ci/validate-lab.sh, which swaps in a local copy of the module.
# The module's shared setup (sandbox-setup.sh in the image: Docker/DNS wait, demo clone, Editor,
# Dev Dashboard, dapr init) runs first. The lab script is lab-setup.sh (starts the pre-build); the
# module inlines it into the VM startup script because the lab's files are not on the VM.
# Publish the module version in Instruqt (Building blocks > Modules > Publish version) BEFORE
# merging a change to `version` here. Every push syncs the lab and resolves this exact version; a
# push that pins a not-yet-published version leaves the lab on "failed to read hcl files: ...
# version X of diagrid/dapr-sandbox is not published: not found" until the next push.
module "sandbox" {
  source  = "diagrid/dapr-sandbox"
  version = "2.0.0"

  variables = {
    dapr_runtime_version = variable.dapr_runtime_version
    demo_repo_ref        = variable.tracks_src_ref
    editor_folder        = "pubsub"
    lab_startup_script   = file("scripts/lab-setup.sh")
  }
}
