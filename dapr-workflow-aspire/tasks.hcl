# Page checks. dapr-workflow-aspire is the one 2.0 lab with page checks (no solve): it builds one
# app from scratch, so each page must start from a working solution. One `task` per page, listed in
# that page's `activities` in pages.hcl and shown with `<instruqt-task id="...">` as the page's last
# section. Each check is a read-only script in `<page>/scripts/check-*.sh` that names the step to
# redo in its `failure_message`. Task IDs: create_solution, write_workflow, orchestrate, run_inspect.
# A task without conditions is not listed by any page yet: the build plan's Tasks 6 and 7 add each
# page's conditions (one per check, with its failure_message), its `activities` entry in pages.hcl
# and the page's `<instruqt-task id="...">`.

resource "task" "create_solution" {
  description = "Check that the solution, the Engineering project and apphost.run.json are in place"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root/university-labs/workflow-aspire"
    timeout           = "30s"
  }

  condition "solution" {
    description = "The MeridianDiagnostics solution exists"

    check {
      script          = "1-create-the-solution/scripts/check-solution.sh"
      failure_message = "MeridianDiagnostics/apphost.cs is missing. Redo section 2, Create the Aspire solution: run the cd command and then the aspire new command in the Aspire CLI window."
    }
  }

  condition "engineering" {
    description = "The Engineering project exists"

    check {
      script          = "1-create-the-solution/scripts/check-engineering.sh"
      failure_message = "MeridianDiagnostics/Engineering/Engineering.csproj is missing. Redo section 3, Add the Engineering project: run the dotnet new web command in the Aspire CLI window."
    }
  }

  condition "dapr_workflow" {
    description = "The Engineering project references Dapr.Workflow"

    check {
      script          = "1-create-the-solution/scripts/check-dapr-workflow.sh"
      failure_message = "Engineering.csproj does not reference the Dapr.Workflow package. Redo section 3, Add the Engineering project: run the dotnet add command in the Aspire CLI window."
    }
  }

  condition "launch_profile" {
    description = "apphost.run.json binds the Aspire dashboard to 0.0.0.0:17000"

    check {
      script          = "1-create-the-solution/scripts/check-launch-profile.sh"
      failure_message = "MeridianDiagnostics/apphost.run.json does not bind the Aspire dashboard to http://0.0.0.0:17000. Redo section 4, Open the dashboard to the sandbox: run the command that writes apphost.run.json in the Aspire CLI window."
    }
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

  condition "workflow" {
    description = "DiagnosticsWorkflow.cs holds the workflow"

    check {
      script          = "2-write-the-workflow/scripts/check-workflow.sh"
      failure_message = "MeridianDiagnostics/Engineering/DiagnosticsWorkflow.cs is missing or does not hold the DiagnosticsWorkflow class. Redo section 2, Add the workflow: create the file in the Editor tab, paste the code block into it and save it."
    }
  }

  condition "activities" {
    description = "Activities.cs holds the three activities"

    check {
      script          = "2-write-the-workflow/scripts/check-activities.sh"
      failure_message = "MeridianDiagnostics/Engineering/Activities.cs is missing or does not hold all three activity classes. Redo section 3, Add the activities: create the file in the Editor tab, paste the whole code block into it and save it."
    }
  }

  condition "program" {
    description = "Program.cs registers the workflow"

    check {
      script          = "2-write-the-workflow/scripts/check-program.sh"
      failure_message = "MeridianDiagnostics/Engineering/Program.cs does not register the workflow. Redo section 4, Register the workflow: run the command that writes Program.cs in the Aspire CLI window."
    }
  }

  condition "build" {
    description = "The Engineering project builds"

    check {
      script          = "2-write-the-workflow/scripts/check-build.sh"
      failure_message = "The Engineering project does not build. Run the dotnet build command of section 5 in the Aspire CLI window to see the errors, then compare the file they name with its code block in section 2 or 3 and save it."
    }
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
