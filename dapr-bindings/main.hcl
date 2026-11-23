resource "lab" "main" {
  title       = "Dapr Bindings - Input and Output Bindings with Cron and PostgreSQL"
  description = <<-EOT
    *To begin, click the **Start** button. Setting up your sandbox takes around 2-3 minutes. Meanwhile, click the full screen icon in the top right to give the lab more space.*

    In this self-paced track, you'll learn:
    - What an input binding is, and how a cron binding calls your app on a schedule through a route named after the component, without any Dapr code in the app
    - What an output binding is, and how the PostgreSQL binding runs SQL for your app with the `exec` and `query` operations
    - When to use the State API and when to use a binding, with both pointed at the same database
    - How bindings combine with service invocation in one flow between two apps

    You'll probably need around 25 minutes to complete the 4 labs.

    The sandbox is available for 30 minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the track.

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
    chapter "bindings" {
      title = "Dapr Bindings"

      page "cron_input_binding" {
        reference = resource.page.cron_input_binding
      }

      page "postgres_output_binding" {
        reference = resource.page.postgres_output_binding
      }

      page "state_vs_binding" {
        reference = resource.page.state_vs_binding
      }

      page "subspace_beacon" {
        reference = resource.page.subspace_beacon
      }
    }
  }
}
