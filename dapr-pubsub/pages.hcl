resource "page" "subscription_types" {
  title = "Subscription types"
  file  = "1-subscription-types/assignment.md"
}

resource "page" "streaming_subscriptions" {
  title = "Streaming subscriptions"
  file  = "2-streaming-subscriptions/assignment.md"
}

resource "page" "cloudevents" {
  title = "CloudEvents and raw payloads"
  file  = "3-cloudevents/assignment.md"
}

resource "page" "bulk_messages" {
  title = "Bulk messages"
  file  = "4-bulk-messages/assignment.md"
}

resource "page" "routing_and_dead_letters" {
  title = "Routing and dead letters"
  file  = "5-routing-and-dead-letters/assignment.md"
}

resource "page" "swap_the_broker" {
  title = "Swap the broker"
  file  = "6-swap-the-broker/assignment.md"
}
