resource "task" "subscription_types" {
  description = "Check that both subscribers receive an order and are registered as DECLARATIVE and PROGRAMMATIC"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root"
    timeout           = "30s"
  }

  condition "apps_running" {
    description = "order-api, shipping and invoicing answer"

    check {
      script          = "1-subscription-types/scripts/check-apps-running.sh"
      failure_message = "order-api, shipping and invoicing do not all answer on ports 5101, 5102 and 5103. Is 'dapr run -f .' running in your Demo1 folder (Demo1-Subscriptions or demo1-subscriptions)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    }

    solve {
      script = "1-subscription-types/scripts/solve.sh"

      config {
        timeout = "180s"
      }
    }
  }

  condition "declarative" {
    description = "Shipping's subscription is DECLARATIVE"

    check {
      script          = "1-subscription-types/scripts/check-declarative.sh"
      failure_message = "The sidecar of shipping (port 3511) does not list the orders subscription as DECLARATIVE. Check that subscription-shipping.yaml is in the resources folder of the demo and restart 'dapr run -f .'."
    }
  }

  condition "programmatic" {
    description = "Invoicing's subscription is PROGRAMMATIC"

    check {
      script          = "1-subscription-types/scripts/check-programmatic.sh"
      failure_message = "The sidecar of invoicing (port 3512) does not list the orders subscription as PROGRAMMATIC. Check the Dapr CLI window for errors from the invoicing app."
    }
  }

  condition "both_received" {
    description = "Shipping and invoicing both received an order"

    check {
      script          = "1-subscription-types/scripts/check-both-received.sh"
      failure_message = "Shipping and invoicing have not both logged 'received order' yet. Send an order with the curl command in step 4 and run the check again."
    }
  }
}
