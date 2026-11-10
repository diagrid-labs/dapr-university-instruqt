resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  # Right side: one panel on top with two tabs, the Editor (open by default) and the Dev
  # Dashboard, which replaces the Editor view when selected; underneath, the two terminals side by
  # side, so both stay visible (the assignments' Run buttons only send commands to a terminal that
  # is shown on the current page). The terminal columns have no width so they share the row equally.
  column {
    width = "60"

    row {
      height = "60"

      tab "editor" {
        target = resource.service.editor
        title  = "Editor"
        active = true
      }

      tab "dev_dashboard" {
        target = resource.service.dev_dashboard
        title  = "Dev Dashboard"
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
