resource "lab" "main" {
  title       = "Dapr Secrets - Read, Scope, and Swap Secret Stores"
  description = <<-EOT
    In this self-paced lab, you'll learn:
    - Why a secret store beats a config file or an environment variable, and how an app reads a secret through the Dapr Secrets API
    - How to configure the local file secret store, call the single and bulk secret endpoints, and let another component pull its password from the store with `secretKeyRef`
    - How to scope secrets so one app can read a secret and another app is refused
    - How to swap the local file store for HashiCorp Vault without changing any application code

    You'll probably need around 28 minutes to complete the 4 labs.

    The sandbox is available for 30 minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the lab.
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
    chapter "secrets" {
      title = "Dapr Secrets"

      page "what_is_the_secrets_api" {
        reference = resource.page.what_is_the_secrets_api
      }

      page "component_and_parameters" {
        reference = resource.page.component_and_parameters
      }

      page "secret_scoping" {
        reference = resource.page.secret_scoping
      }

      page "swap_the_provider" {
        reference = resource.page.swap_the_provider
      }
    }
  }
}
