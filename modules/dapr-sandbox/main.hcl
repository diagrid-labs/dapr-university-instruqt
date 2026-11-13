variable "cpu" {
  description = "Number of vCPUs for the sandbox VM"
  default     = 4
}

variable "memory" {
  description = "Memory for the sandbox VM in MB"
  default     = 8192
}

variable "dapr_runtime_version" {
  description = "Dapr runtime version that dapr init installs (the lab's own pin); the setup fails when it is empty"
  default     = ""
}

variable "demo_repo_url" {
  description = "Git URL of the demo repo cloned to /root/ai-agent-tracks-instruqt"
  default     = "https://github.com/diagrid-labs/ai-agent-tracks-instruqt.git"
}

variable "demo_repo_ref" {
  description = "Commit SHA (or ref) of the demo repo to check out; the setup fails when it is empty"
  default     = ""
}

variable "editor_folder" {
  description = "Folder inside the demo clone that the Editor tab opens, e.g. \"pubsub\"; the setup fails when it is empty"
  default     = ""
}

variable "lab_startup_script" {
  description = "Lab-specific setup script content, run by the VM on boot (pass file(\"scripts/...\") from the lab)"
  default     = ""
}

variable "lab_environment" {
  description = "Environment variables for the lab startup script. Learners can read these, so never pass credentials."
  default     = {}
}

resource "vm" "sandbox" {
  image {
    name = variable.image_ref
  }

  resources {
    cpu    = variable.cpu
    memory = variable.memory
  }

  # The shared setup (sourced from the image) and the lab script run in a subshell so an early
  # `exit` in them cannot skip or fake the marker;
  # a failing lab script fails this script (set -e) before the marker is written.
  startup_script = "#!/usr/bin/env bash\nset -euo pipefail\n(\nexport DAPR_RUNTIME_VERSION='${variable.dapr_runtime_version}'\nexport DEMO_REPO_URL='${variable.demo_repo_url}'\nexport DEMO_REPO_REF='${variable.demo_repo_ref}'\nexport EDITOR_FOLDER='${variable.editor_folder}'\nsource /usr/local/lib/dapr-sandbox/sandbox-setup.sh\n${variable.lab_startup_script}\n)\nmkdir -p /var/lib/lab-setup\ntouch /var/lib/lab-setup/ready\n"
  environment    = variable.lab_environment

  # No health_check: Instruqt keeps the sandbox in "Creating sandbox" until startup_script has
  # finished (and fails creation when it exits non-zero), which is exactly what a readiness check
  # was meant to enforce. An exec health check that only tested that marker kept timing out
  # on a VM even after the script had written it, so it is gone. The marker stays as a manual
  # check: `ls /var/lib/lab-setup/ready` in a lab terminal.
}

output "vm" {
  description = "The sandbox VM, used by labs as the target of terminals, editors and tasks"
  value       = resource.vm.sandbox
}
