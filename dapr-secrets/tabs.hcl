# The Editor tab: code-server (VS Code in the browser) that lab-setup.sh runs on the VM on port 8888,
# opened on the demo folder. The built-in `editor` resource showed no files for a VM target.
resource "service" "editor" {
  target = module.sandbox.output.vm
  port   = 8888
  scheme = "http"
  path   = "/"
}

# The Dev Dashboard tab: Diagrid's Dapr Dev Dashboard, which lab-setup.sh runs on the VM on port 9090.
# Outside container posture it rejects a non-loopback Host header ("forbidden: non-local Host
# header") and cross-origin writes, so the tab presents itself as localhost.
resource "service" "dev_dashboard" {
  target = module.sandbox.output.vm
  port   = 9090
  scheme = "http"
  path   = "/"

  custom_request_headers = {
    "Host"   = "localhost:9090"
    "Origin" = "http://localhost:9090"
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
