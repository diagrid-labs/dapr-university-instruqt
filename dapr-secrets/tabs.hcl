resource "editor" "code" {
  workspace "secrets" {
    target    = module.sandbox.output.vm
    directory = "/root/ai-agent-tracks-instruqt/secrets"
  }

  # TEMPORARY diagnostic: a world-readable folder outside /root, created by lab-setup.sh. If this
  # workspace shows README.txt while "secrets" stays empty, the editor works on the VM and the
  # problem is the /root path; if both are empty, the editor cannot show VM files at all.
  workspace "probe" {
    target    = module.sandbox.output.vm
    directory = "/opt/editor-probe"
  }
}

resource "terminal" "dapr_cli" {
  target            = module.sandbox.output.vm
  shell             = "/bin/bash"
  working_directory = "/root/ai-agent-tracks-instruqt/secrets"
}

resource "terminal" "curl" {
  target            = module.sandbox.output.vm
  shell             = "/bin/bash"
  working_directory = "/root/ai-agent-tracks-instruqt/secrets"
}
