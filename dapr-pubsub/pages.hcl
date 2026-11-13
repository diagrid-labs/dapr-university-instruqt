resource "page" "subscription_types" {
  title = "Subscription types"
  file  = "1-subscription-types/assignment.md"

  activities = {
    subscription_types = resource.task.subscription_types
  }
}

resource "page" "streaming_subscriptions" {
  title = "Streaming subscriptions"
  file  = "2-streaming-subscriptions/assignment.md"

  activities = {
    streaming = resource.task.streaming
  }
}

resource "page" "cloudevents" {
  title = "CloudEvents and raw payloads"
  file  = "3-cloudevents/assignment.md"

  activities = {
    cloudevents = resource.task.cloudevents
  }
}

resource "page" "bulk_messages" {
  title = "Bulk messages"
  file  = "4-bulk-messages/assignment.md"

  activities = {
    bulk_messages = resource.task.bulk_messages
  }
}

resource "page" "routing_and_dead_letters" {
  title = "Routing and dead letters"
  file  = "5-routing-and-dead-letters/assignment.md"

  activities = {
    routing = resource.task.routing
  }
}

resource "page" "swap_the_broker" {
  title = "Swap the broker"
  file  = "6-swap-the-broker/assignment.md"

  activities = {
    swap_broker = resource.task.swap_broker
  }
}
