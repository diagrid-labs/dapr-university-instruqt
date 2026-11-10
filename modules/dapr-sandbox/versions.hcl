# Single source of truth for the toolchain baked into the sandbox image.
# scripts/render-image-script.sh reads these with tools/track-tester/ci/read_pin.py, so keep each
# pin a plain `variable "<name>" { default = "<value>" }` block.

variable "image_ref" {
  description = "VM image the sandbox boots from. Replaced by the Image Builder output (diagrid/<image-name>:<tag>) once the image is built."
  default     = "diagrid/dapr-sandbox:v1"
}

variable "dotnet_sdk_channel" {
  description = ".NET SDK channel, installed as dotnet-sdk-<channel>"
  default     = "10.0"
}

variable "java_version" {
  description = "OpenJDK major version, installed as openjdk-<version>-jdk"
  default     = "17"
}

variable "node_major" {
  description = "Node.js major version (NodeSource LTS line)"
  default     = "24"
}

variable "dapr_cli_version" {
  description = "Dapr CLI version"
  default     = "1.19.1"
}

variable "prewarm_dapr_runtime_version" {
  description = "Dapr runtime version whose container images are pre-pulled into the image. Must match the lab's dapr_runtime_version for the pre-pull to help."
  default     = "1.19.1"
}
