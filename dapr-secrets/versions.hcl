# Single source of truth for the dapr-secrets lab pins. Keep each pin a plain
# `variable "<name>" { default = "<value>" }` block: tools/track-tester/ci/read_pin.py reads them.
# The sandbox toolchain pins live in modules/dapr-sandbox/versions.hcl.

variable "dapr_runtime_version" {
  description = "Dapr runtime the lab initialises (dapr init --runtime-version). Must equal prewarm_dapr_runtime_version in modules/dapr-sandbox/versions.hcl."
  default     = "1.18.7"
}

variable "tracks_src_ref" {
  description = "Commit of diagrid-labs/ai-agent-tracks-instruqt that the lab checks out after cloning."
  default     = "b1da54839b14ee1bb124914b915f78200a8f5f4e"
}
