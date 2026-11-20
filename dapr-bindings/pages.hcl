resource "page" "cron_input_binding" {
  title = "Cron input binding"
  file  = "1-cron-input-binding/assignment.md"
}

resource "page" "postgres_output_binding" {
  title = "PostgreSQL output binding"
  file  = "2-postgres-output-binding/assignment.md"
}

resource "page" "state_vs_binding" {
  title = "State API vs binding"
  file  = "3-state-vs-binding/assignment.md"
}

resource "page" "subspace_beacon" {
  title = "Combining bindings with service invocation"
  file  = "4-subspace-beacon/assignment.md"
}
