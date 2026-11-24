# Page checks. dapr-workflow-aspire is the one 2.0 lab with page checks (no solve): it builds one
# app from scratch, so each page must start from a working solution. One `task` per page, listed in
# that page's `activities` in pages.hcl and shown with `<instruqt-task id="...">` as the page's last
# section. Each check is a read-only script in `<page>/scripts/check-*.sh` that names the step to
# redo in its `failure_message`. Task IDs: create_solution, write_workflow, orchestrate, run_inspect.
# The tasks below have no conditions and no page lists them yet: the build plan's Tasks 4 to 7 add
# each page's conditions (one per check, with its failure_message), its `activities` entry in
# pages.hcl and the page's `<instruqt-task id="...">`.

resource "task" "create_solution" {
  description = "Check that the solution, the Engineering project and apphost.run.json are in place"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root/university-labs/workflow-aspire"
    timeout           = "30s"
  }
}

resource "task" "write_workflow" {
  description = "Check that the workflow, the activities and Program.cs are in place and that Engineering builds"

  # Raised from 30s: the check builds Engineering.
  config {
    target            = module.sandbox.output.vm
    working_directory = "/root/university-labs/workflow-aspire"
    timeout           = "120s"
  }
}

resource "task" "orchestrate" {
  description = "Check that the AppHost describes the app and that the app and the Dev Dashboard answer"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root/university-labs/workflow-aspire"
    timeout           = "30s"
  }
}

resource "task" "run_inspect" {
  description = "Check that a diagnostics workflow has completed"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root/university-labs/workflow-aspire"
    timeout           = "30s"
  }
}
