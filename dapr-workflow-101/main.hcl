resource "lab" "main" {
  title       = "Dapr Workflow 101 - Durable Execution, Patterns and Management"
  description = <<-EOT
    *To begin, click the **Start** button. Setting up your sandbox takes around 2-3 minutes. Meanwhile, click the full screen icon in the top right to give the lab more space.*

    In this self-paced track, you'll learn:
    - What a workflow and an activity are, and how a workflow survives a crash and carries on from the last completed step
    - How task chaining runs activities in sequence, with each output the next input
    - How fan-out/fan-in runs activities in parallel and combines their results
    - How the monitor pattern checks a value until it is stable, with a durable timer and continue-as-new
    - How a workflow waits for a human decision, an external event, with a timeout
    - How to pause, resume, terminate and purge a running workflow, from your app and with the Dapr CLI

    You'll probably need around 40 minutes to complete the 6 labs.

    The sandbox is available for 45 minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the track.

    Enjoy some cellular automata art while the sandbox is being prepared.

    <iframe src="https://www.diagrid.io/demos/sketches/dapr-university.html" width="500" height="500"></iframe>
  EOT

  settings {
    timelimit {
      duration   = "45m"
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
    chapter "workflow" {
      title = "Dapr Workflow 101"

      page "durable_execution" {
        reference = resource.page.durable_execution
      }

      page "task_chaining" {
        reference = resource.page.task_chaining
      }

      page "fan_out_fan_in" {
        reference = resource.page.fan_out_fan_in
      }

      page "monitor" {
        reference = resource.page.monitor
      }

      page "human_in_the_loop" {
        reference = resource.page.human_in_the_loop
      }

      page "management" {
        reference = resource.page.management
      }
    }
  }
}
