resource "lab" "main" {
  title       = "Dapr Workflow with .NET Aspire"
  description = <<-EOT
    *To begin, click the **Start** button. Setting up your sandbox takes around 2-3 minutes. Meanwhile, click the full screen icon in the top right to give the lab more space.*

    In this self-paced track, you'll learn:
    - How `aspire new` and a single-file `apphost.cs` describe the whole app
    - What a workflow and an activity are, and why the workflow code must be deterministic
    - How the fan-out/fan-in pattern runs activities in parallel with `Task.WhenAll`
    - How the AppHost adds a Dapr sidecar, a state store component and an executable resource
    - How a workflow resumes from its last completed step after the app restarts

    You'll probably need around 25 minutes to complete the 4 labs.

    The sandbox is available for 30 minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the track.

    Complete the track to collect the Dapr University Workflow Aspire badge.

    <img src="https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow-aspire/4-run-and-inspect/images/Diagrid-Dapr-Uni-badge-wf-aspire_x300.png?raw=true" alt="Dapr University Workflow Aspire badge" width="192" height="192">

    Enjoy some cellular automata art while the sandbox is being prepared.

    <iframe src="https://www.diagrid.io/demos/sketches/dapr-university.html" width="500" height="500"></iframe>
  EOT

  settings {
    timelimit {
      duration   = "30m"
      extend     = "10m"
      show_timer = true
    }

    idle {
      enabled      = true
      timeout      = "10m"
      show_warning = true
    }
  }

  layout = resource.layout.main

  content {
    chapter "workflow_aspire" {
      title = "Dapr Workflow with .NET Aspire"

      page "create_the_solution" {
        reference = resource.page.create_the_solution
      }

      page "write_the_workflow" {
        reference = resource.page.write_the_workflow
      }

      page "orchestrate_with_aspire" {
        reference = resource.page.orchestrate_with_aspire
      }

      page "run_and_inspect" {
        reference = resource.page.run_and_inspect
      }
    }
  }
}
