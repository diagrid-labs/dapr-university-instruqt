resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  # Right side: one panel on top with three tabs, the Dev Dashboard, RabbitMQ and the Editor (open by default),
  # each replacing the other when selected; underneath, the two terminals side by
  # side, so both stay visible (the assignments' Run buttons only send commands to a terminal that
  # is shown on the current page). The terminal columns have no width so they share the row equally.
  column {
    width = "60"

    row {
      height = "60"

      # The Editor is declared last on purpose: with the Editor declared first and
      # `active = true`, the lab still opened on the last tab in the panel. So the Dev Dashboard
      # and RabbitMQ come first and the Editor, the tab the pages start on, comes last.
      tab "dev_dashboard" {
        target = resource.service.dev_dashboard
        title  = "Dev Dashboard"
        active = false
      }

      tab "rabbitmq" {
        target = resource.service.rabbitmq
        title  = "RabbitMQ"
        active = false
      }

      tab "editor" {
        target = resource.service.editor
        title  = "Editor"
        active = true
      }
    }

    row {
      height = "40"

      column {
        tab "dapr_cli" {
          target = resource.terminal.dapr_cli
          title  = "Dapr CLI"
          active = true
        }
      }

      column {
        tab "curl" {
          target = resource.terminal.curl
          title  = "curl"
          active = true
        }
      }
    }
  }
}
