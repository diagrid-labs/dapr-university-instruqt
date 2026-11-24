# The Editor tab: code-server (VS Code in the browser) that the dapr-sandbox module runs on the VM on port 8888,
# opened on the workspace folder. The built-in `editor` resource showed no files for a VM target.
resource "service" "editor" {
  target = module.sandbox.output.vm
  port   = 8888
  scheme = "http"
  path   = "/"
}

# The Aspire tab: the Aspire dashboard that `aspire run` starts (page 3). apphost.run.json binds it
# to 0.0.0.0:17000 with anonymous access (ASPIRE_DASHBOARD_UNSECURED_ALLOW_ANONYMOUS), which also
# answers a non-loopback Host header, so the tab needs no custom headers. It shows "trying to
# connect" until `aspire run`.
resource "service" "aspire_dashboard" {
  target = module.sandbox.output.vm
  port   = 17000
  scheme = "http"
  path   = "/"
}

# The Dev Dashboard tab: Diagrid's Dapr Dev Dashboard. lab-setup.sh stops the module's copy, and the
# AppHost runs it as the dev-dashboard resource on port 9090 (page 3), so the tab is empty until
# `aspire run`. Outside container posture it rejects a non-loopback Host header ("forbidden:
# non-local Host header") and cross-origin writes, so the tab presents itself as localhost.
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

resource "terminal" "aspire_cli" {
  target            = module.sandbox.output.vm
  shell             = "/bin/bash"
  working_directory = "/root/university-labs/workflow-aspire"
}

resource "terminal" "curl" {
  target            = module.sandbox.output.vm
  shell             = "/bin/bash"
  working_directory = "/root/university-labs/workflow-aspire"
}
