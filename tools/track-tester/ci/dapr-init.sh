# shellcheck shell=bash
# Sourced by the setup-dapr-*.sh scripts. Defines dapr_init_with_retry.
#
# On GitHub runners, `dapr init` sometimes fails because a host port that one of its containers
# publishes is briefly in use ("failed to bind host port 0.0.0.0:50006/tcp: address already in
# use"). That is a one-off clash on the runner, so in CI the half-finished init is removed and
# `dapr init` runs again. On a developer machine it fails right away instead: the cleanup runs
# `dapr uninstall --all`, which would also remove the developer's Dapr containers.
#
# Settings: DAPR_INIT_ATTEMPTS (default 3) and DAPR_INIT_RETRY_DELAY (seconds, default 10, doubled
# after each failed attempt).

dapr_init_with_retry() {
  local attempts="${DAPR_INIT_ATTEMPTS:-3}"
  local delay="${DAPR_INIT_RETRY_DELAY:-10}"
  local attempt=1
  while true; do
    if dapr init; then
      return 0
    fi
    if [ -z "${CI:-}" ]; then
      echo "ERROR: dapr init failed. Not retrying outside CI, because the cleanup runs 'dapr uninstall --all'." >&2
      return 1
    fi
    if [ "$attempt" -ge "$attempts" ]; then
      echo "ERROR: dapr init failed $attempt times." >&2
      return 1
    fi
    echo "dapr init failed (attempt $attempt of $attempts); removing the Dapr containers and retrying in ${delay}s." >&2
    dapr uninstall --all >/dev/null 2>&1 || true
    sleep "$delay"
    delay=$((delay * 2))
    attempt=$((attempt + 1))
  done
}
