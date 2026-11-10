resource "layout" "main" {
  column {
    width = "40"

    instructions {}
  }

  column {
    width = "60"

    tab "editor" {
      target = resource.editor.code
      title  = "Editor"
      active = true
    }

    tab "dapr_cli" {
      target = resource.terminal.dapr_cli
      title  = "Dapr CLI"
    }

    tab "curl" {
      target = resource.terminal.curl
      title  = "curl"
    }
  }
}
