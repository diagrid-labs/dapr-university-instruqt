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

resource "task" "streaming" {
  description = "Check that the warehouse receives orders over a STREAMING subscription"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root"
    timeout           = "30s"
  }

  condition "apps_running" {
    description = "order-api and the warehouse sidecar answer"

    check {
      script          = "2-streaming-subscriptions/scripts/check-apps-running.sh"
      failure_message = "order-api (port 5101) or the sidecar of the warehouse (port 3511) does not answer. Is 'dapr run -f .' running in your Demo2 folder (Demo2-Streaming or demo2-streaming)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    }

    solve {
      script = "2-streaming-subscriptions/scripts/solve.sh"

      config {
        timeout = "180s"
      }
    }
  }

  condition "streaming" {
    description = "The warehouse's subscription is STREAMING"

    check {
      script          = "2-streaming-subscriptions/scripts/check-streaming.sh"
      failure_message = "The sidecar of the warehouse (port 3511) does not list the orders subscription as STREAMING. Check the Dapr CLI window for errors from the warehouse app, then wait a few seconds and run the check again."
    }
  }

  condition "received" {
    description = "The warehouse received an order"

    check {
      script          = "2-streaming-subscriptions/scripts/check-received.sh"
      failure_message = "The warehouse has not logged 'warehouse received order' yet. Send an order with the curl command in step 4 and run the check again."
    }
  }
}

resource "task" "cloudevents" {
  description = "Check that shipping received one order with its CloudEvent envelope and one as a raw payload"

  config {
    target            = module.sandbox.output.vm
    working_directory = "/root"
    timeout           = "30s"
  }

  condition "apps_running" {
    description = "order-api and shipping answer"

    check {
      script          = "3-cloudevents/scripts/check-apps-running.sh"
      failure_message = "order-api (port 5101) or shipping (port 5102) does not answer, or another page's demo is still running. Is 'dapr run -f .' running in your Demo3 folder (Demo3-CloudEvents or demo3-cloud-events)? If another page's demo is still running, press Ctrl+C in the Dapr CLI window first."
    }

    solve {
      script = "3-cloudevents/scripts/solve.sh"

      config {
        timeout = "180s"
      }
    }
  }

  condition "envelope" {
    description = "Shipping received an order with a CloudEvent envelope"

    check {
      script          = "3-cloudevents/scripts/check-envelope.sh"
      failure_message = "Shipping has not logged both 'received with envelope' and 'parsed CloudEvent' yet. Send an order with the first curl command in step 3 and run the check again."
    }
  }

  condition "raw" {
    description = "Shipping received a raw order"

    check {
      script          = "3-cloudevents/scripts/check-raw.sh"
      failure_message = "Shipping has not logged 'received raw:' yet. Send an order to /orders/raw with the curl command in step 4 and run the check again."
    }
  }
}
