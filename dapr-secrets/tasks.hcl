resource "task" "scoping" {
  description = "Check that app B is refused orderdb-password and still reads payments-api-key"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root"
    timeout           = "30s"
  }

  condition "config_present" {
    description = "config-app-b.yaml is present"

    check {
      script          = "3-secret-scoping/scripts/check-config-present.sh"
      failure_message = "config-app-b.yaml is missing from the resources folder of the scoping demo (Demo2-Scoping or demo2-scoping). Did the lab setup finish?"
    }

    solve {
      script = "3-secret-scoping/scripts/solve.sh"

      config {
        timeout = "180s"
      }
    }
  }

  condition "app_a_reads" {
    description = "App A reads orderdb-password"

    check {
      script          = "3-secret-scoping/scripts/check-app-a-reads.sh"
      failure_message = "App A cannot read orderdb-password. Is 'dapr run -f .' running in your scoping demo folder (Demo2-Scoping or demo2-scoping)?"
    }
  }

  condition "app_b_answers" {
    description = "App B answers on port 5003"

    check {
      script          = "3-secret-scoping/scripts/check-app-b-answers.sh"
      failure_message = "App B does not answer on port 5003. Is 'dapr run -f .' running in your scoping demo folder (Demo2-Scoping or demo2-scoping)?"
    }
  }

  condition "app_b_refused" {
    description = "App B is refused orderdb-password"

    check {
      script          = "3-secret-scoping/scripts/check-app-b-refused.sh"
      failure_message = "App B is not refused orderdb-password with HTTP 403. If it can still read it, did you remove the '# ' in front of configFilePath in dapr.yaml, and restart 'dapr run -f .' afterwards? Otherwise check the Dapr CLI window for errors."
    }
  }

  condition "app_b_allowed" {
    description = "App B reads payments-api-key"

    check {
      script          = "3-secret-scoping/scripts/check-app-b-allowed.sh"
      failure_message = "App B is refused payments-api-key as well. It is in allowedSecrets, so check config-app-b.yaml."
    }
  }
}

resource "task" "swap_provider" {
  description = "Check that the app reads orderdb-password from Vault"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root"
    timeout           = "30s"
  }

  condition "app_answers" {
    description = "The app answers on port 5001"

    check {
      script          = "4-swap-the-provider/scripts/check-app-answers.sh"
      failure_message = "The app does not answer on port 5001. Is 'dapr run -f .' running in your swap demo folder (Demo3-SwapProvider or demo3-swap-provider)?"
    }

    solve {
      script = "4-swap-the-provider/scripts/solve.sh"

      config {
        timeout = "180s"
      }
    }
  }

  condition "previous_apps_stopped" {
    description = "The apps from the scoping lab are stopped"

    check {
      script          = "4-swap-the-provider/scripts/check-previous-apps-stopped.sh"
      failure_message = "App A or App B from the scoping demo is still running, and the app for this lab is not. Press Ctrl+C in the Dapr CLI window to stop them, then start the app with 'dapr run -f .' from your swap demo folder (Demo3-SwapProvider or demo3-swap-provider)."
    }
  }

  condition "vault_loaded" {
    description = "Dapr loaded the Vault secret store"

    check {
      script          = "4-swap-the-provider/scripts/check-vault-loaded.sh"
      failure_message = "The app isn't reading from Vault yet. Is secretstore-vault.yaml the component Dapr loaded? Stop the running app with Ctrl+C and start it with 'dapr run -f .' from the swap demo folder (Demo3-SwapProvider or demo3-swap-provider), not from the demo 1 folder."
    }
  }

  condition "app_reads" {
    description = "The app reads orderdb-password from Vault"

    check {
      script          = "4-swap-the-provider/scripts/check-app-reads.sh"
      failure_message = "Dapr loaded the Vault component, but the app cannot read orderdb-password. Is Vault running ('docker ps') and does it hold the secrets? Check the Dapr CLI window for errors."
    }
  }
}
