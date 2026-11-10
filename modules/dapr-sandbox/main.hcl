variable "cpu" {
  description = "Number of vCPUs for the sandbox VM"
  default     = 4
}

variable "memory" {
  description = "Memory for the sandbox VM in MB"
  default     = 8192
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

  # The lab script runs in a subshell so an early `exit` in it cannot skip or fake the marker;
  # a failing lab script fails this script (set -e) before the marker is written.
  startup_script = "#!/usr/bin/env bash\nset -euo pipefail\n(\n:\n${variable.lab_startup_script}\n)\nmkdir -p /var/lib/lab-setup\ntouch /var/lib/lab-setup/ready\n"
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
