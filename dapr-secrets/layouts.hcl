resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  # Right side: the Editor on top, and the two terminals side by side underneath it, so both
  # terminals stay visible (the assignments' Run buttons only send commands to a terminal that is
  # shown on the current page).
  column {
    width = "60"

    row {
      height = "60"

      tab "editor" {
        target = resource.service.editor
        title  = "Editor"
        active = true
      }
    }

    row {
      height = "40"

      column {
        width = "50"

        tab "dapr_cli" {
          target = resource.terminal.dapr_cli
          title  = "Dapr CLI"
          active = true
        }
      }

      column {
        width = "50"

        tab "curl" {
          target = resource.terminal.curl
          title  = "curl"
          active = true
        }
      }
    }
  }
}
