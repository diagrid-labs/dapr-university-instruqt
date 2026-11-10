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

  startup_script = variable.lab_startup_script
  environment    = variable.lab_environment

  # The lab startup script ends by creating /var/lib/lab-setup/ready, so the sandbox only
  # counts as ready once the lab setup has finished.
  health_check {
    timeout = "120s"

    exec {
      script = file("scripts/check-ready.sh")
    }
  }
}

output "vm" {
  description = "The sandbox VM, used by labs as the target of terminals, editors and tasks"
  value       = resource.vm.sandbox
}
