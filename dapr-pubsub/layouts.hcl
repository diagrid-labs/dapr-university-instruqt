# Two layouts that differ only in the RabbitMQ tab. RabbitMQ only runs from page 6 on (the learner
# starts it there), so pages 1 to 5 use `main` and page 6 uses `broker` (`layout` on the page entry
# in main.hcl). Otherwise the tab shows "We're trying to connect to the service" for five pages.
# Keep the two layouts the same apart from that tab.

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

      # The Editor is declared last on purpose: with the Editor declared first and
      # `active = true`, the lab still opened on the last tab in the panel. So the Dev Dashboard
      # comes first and the Editor, the tab the pages start on, comes last.
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

# Page 6: the `main` layout plus the RabbitMQ management tab between the Dev Dashboard and the
# Editor (the Editor stays last, see the comment in `main`).
resource "layout" "broker" {
  column {
    width = "40"

    instructions {}
  }

  column {
    width = "60"

    row {
      height = "60"

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
