resource "page" "what_is_dapr" {
  title = "What is Dapr"
  file  = "1-what-is-dapr/assignment.md"
}

resource "page" "dapr_cli" {
  title = "The Dapr CLI"
  file  = "2-dapr-cli/assignment.md"
}

resource "page" "state_management" {
  title = "Use the State Management API"
  file  = "3-state-management-api/assignment.md"
}

resource "page" "service_invocation" {
  title = "Use the Service Invocation API"
  file  = "4-service-invocation-api/assignment.md"
}

resource "page" "pubsub" {
  title = "Use the Pub/Sub API"
  file  = "5-pubsub-api/assignment.md"
}
