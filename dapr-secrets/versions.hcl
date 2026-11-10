# Single source of truth for the dapr-secrets lab pins. Keep each pin a plain
# `variable "<name>" { default = "<value>" }` block: tools/track-tester/ci/read_pin.py reads them.
# The sandbox toolchain pins live in modules/dapr-sandbox/versions.hcl.

variable "dapr_runtime_version" {
  description = "Dapr runtime the lab initialises (dapr init --runtime-version). Must equal prewarm_dapr_runtime_version in modules/dapr-sandbox/versions.hcl."
  default     = "1.19.1"
}

variable "tracks_src_ref" {
  description = "Commit of diagrid-labs/ai-agent-tracks-instruqt that the lab checks out after cloning."
  default     = "b1da54839b14ee1bb124914b915f78200a8f5f4e"
}

# Shared sandbox module, published as diagrid/dapr-sandbox (source: ../modules/dapr-sandbox).
# `instruqt lab validate` cannot resolve registry sources, so validate through
# tools/track-tester/ci/validate-lab.sh, which swaps in a local copy of the module.
# The lab script is seed-vault.sh (defines seed_vault) followed by lab-setup.sh (calls it); the
# module inlines it into the VM startup script because the lab's files are not on the VM.
module "sandbox" {
  source  = "diagrid/dapr-sandbox"
  version = "1.0.0"

  variables = {
    lab_startup_script = "${file("scripts/seed-vault.sh")}\n${file("scripts/lab-setup.sh")}"
    lab_environment = {
      DAPR_RUNTIME_VERSION = variable.dapr_runtime_version
      TRACKS_SRC_REF       = variable.tracks_src_ref
    }
  }
}
