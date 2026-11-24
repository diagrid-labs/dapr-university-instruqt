resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  # Right side: one panel on top with three tabs, the Aspire dashboard, the Dev Dashboard and the
  # Editor (open by default), each replacing the others when selected; underneath, the two
  # terminals side by side, so both stay visible (the assignments' Run buttons only send commands
  # to a terminal that is shown on the current page). The terminal columns have no width so they
  # share the row equally.
  column {
    width = "60"

    row {
      height = "60"

      tab "aspire_dashboard" {
        target = resource.service.aspire_dashboard
        title  = "Aspire"
        active = false
      }

      tab "dev_dashboard" {
        target = resource.service.dev_dashboard
        title  = "Dev Dashboard"
        active = false
      }

      # Declared last on purpose: with the Editor declared first and `active = true`, the
      # dapr-workflow-101 lab still opened on the Dev Dashboard (the last tab in the panel).
      tab "editor" {
        target = resource.service.editor
        title  = "Editor"
        active = true
      }
    }

    row {
      height = "40"

      column {
        tab "aspire_cli" {
          target = resource.terminal.aspire_cli
          title  = "Aspire CLI"
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
