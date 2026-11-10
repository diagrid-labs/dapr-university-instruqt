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

  # The module's startup script writes /var/lib/lab-setup/ready after the lab script succeeds,
  # so the sandbox only counts as ready once the lab setup has finished.
  # The timeout is the failure ceiling (slow boots, Docker start, Demo1 pre-build), not the
  # target: the learner-facing goal is still a sandbox ready in about 1 minute 30 seconds.
  health_check {
    timeout = "300s"

    exec {
      script = "scripts/check-ready.sh"
    }
  }
}

output "vm" {
  description = "The sandbox VM, used by labs as the target of terminals, editors and tasks"
  value       = resource.vm.sandbox
}
