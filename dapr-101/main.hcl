resource "lab" "main" {
  title       = "Dapr 101 - State Management, Service Invocation, and Pub/Sub APIs"
  description = <<-EOT
    *To begin, click the **Start** button. Setting up your sandbox takes around 2-3 minutes. Meanwhile, click the full screen icon in the top right to give the lab more space.*

    In this self-paced track, you'll learn:
    - Why organizations use Dapr to build distributed applications
    - How Dapr works
    - How to use the Dapr CLI for local development
    - How to use the three most popular Dapr APIs: State Management, Service Invocation, and Pub/Sub

    You'll probably need around 20 minutes to complete the 5 labs.

    The sandbox is available for 30 minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the track.

    Complete the track to collect the Dapr University Dapr 101 badge.

    <img src="https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-101/5-pubsub-api/Diagrid-Dapr-Uni-101_x500.png?raw=true" alt="Dapr University Dapr 101 badge" width="320" height="320">

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
    chapter "dapr101" {
      title = "Dapr 101"

      page "what_is_dapr" {
        reference = resource.page.what_is_dapr
      }

      page "dapr_cli" {
        reference = resource.page.dapr_cli
      }

      page "state_management" {
        reference = resource.page.state_management
      }

      page "service_invocation" {
        reference = resource.page.service_invocation
      }

      page "pubsub" {
        reference = resource.page.pubsub
      }
    }
  }
}
