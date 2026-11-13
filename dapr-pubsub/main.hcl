resource "lab" "main" {
  title       = "Pub/Sub deep dive: Subscription types, CloudEvents, Bulk Publishing and Routing"
  description = <<-EOT
    In this self-paced lab, you'll learn:
    - How declarative and programmatic subscriptions differ, and how an app subscribes to a topic in each
    - How a streaming subscription lets an app receive messages without exposing an HTTP endpoint
    - How CloudEvents wrap your messages, and how to publish and receive raw payloads instead
    - How to publish and subscribe to messages in bulk
    - How to route messages by content and send failed messages to a dead-letter topic after retries
    - How to swap Redis for RabbitMQ without changing any application code

    You'll probably need around 42 minutes to complete the 6 labs.

    The sandbox is available for 45 minutes in total, and you can extend that time by 10 minutes. If you are inactive for 10 minutes, the sandbox times out. After a timeout, you need to restart the lab.
  EOT

  settings {
    timelimit {
      duration   = "45m"
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
    chapter "pubsub" {
      title = "Dapr Pub/Sub"

      page "subscription_types" {
        reference = resource.page.subscription_types
      }

      page "streaming_subscriptions" {
        reference = resource.page.streaming_subscriptions
      }

      page "cloudevents" {
        reference = resource.page.cloudevents
      }

      page "bulk_messages" {
        reference = resource.page.bulk_messages
      }

      page "routing_and_dead_letters" {
        reference = resource.page.routing_and_dead_letters
      }

      page "swap_the_broker" {
        reference = resource.page.swap_the_broker
      }
    }
  }
}
