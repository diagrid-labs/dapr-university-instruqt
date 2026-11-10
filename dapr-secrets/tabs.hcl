# The Editor tab: code-server (VS Code in the browser) that lab-setup.sh runs on the VM on port 8888,
# opened on the demo folder. The built-in `editor` resource showed no files for a VM target.
resource "service" "editor" {
  target = module.sandbox.output.vm
  port   = 8888
  scheme = "http"
  path   = "/"
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
