resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  # Right side: the Editor and the Dev Dashboard side by side on top, and the two terminals side
  # by side underneath them, so both terminals stay visible (the assignments' Run buttons only send
  # commands to a terminal that is shown on the current page). Nested columns have no width so
  # they share their row equally.
  column {
    width = "60"

    row {
      height = "60"

      column {
        tab "editor" {
          target = resource.service.editor
          title  = "Editor"
          active = true
        }
      }

      column {
        tab "dev_dashboard" {
          target = resource.service.dev_dashboard
          title  = "Dev Dashboard"
          active = true
        }
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
