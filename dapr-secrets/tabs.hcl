resource "editor" "code" {
  workspace "secrets" {
    target    = module.sandbox.output.vm
    directory = "/root/ai-agent-tracks-instruqt/secrets"
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
