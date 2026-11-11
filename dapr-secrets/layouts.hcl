resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  # Right side: one panel on top with two tabs, the Dev Dashboard and the Editor (open by default),
  # each replacing the other when selected; underneath, the two terminals side by
  # side, so both stay visible (the assignments' Run buttons only send commands to a terminal that
  # is shown on the current page). The terminal columns have no width so they share the row equally.
  column {
    width = "60"

    row {
      height = "60"

      # Declared after the Dev Dashboard on purpose: with the Editor declared first and
      # `active = true`, the lab still opened on the Dev Dashboard (the last tab in the panel).
      tab "dev_dashboard" {
        target = resource.service.dev_dashboard
        title  = "Dev Dashboard"
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
