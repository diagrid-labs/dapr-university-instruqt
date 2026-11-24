"""Tests for tools/track-tester/ci/dapr-init.sh (dapr_init_with_retry), run against a stubbed dapr."""

import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[4]
HELPER = REPO / "tools" / "track-tester" / "ci" / "dapr-init.sh"
SETUP_SCRIPTS = ["setup-dapr-101.sh", "setup-dapr-secrets.sh", "setup-dapr-pubsub.sh", "setup-dapr-workflow.sh"]


def run(tmp_path, init_failures, ci=True, attempts=3):
    """Source the helper and call dapr_init_with_retry with a fake `dapr` whose `init` fails
    `init_failures` times before it succeeds. Returns the result and the dapr calls made."""
    bindir = tmp_path / "bin"
    bindir.mkdir()
    calls = tmp_path / "calls"
    count = tmp_path / "init-count"
    count.write_text("0")
    dapr = bindir / "dapr"
    dapr.write_text(
        "#!/bin/sh\n"
        f'echo "dapr $*" >> "{calls}"\n'
        'if [ "$1" = init ]; then\n'
        f'  n=$(cat "{count}"); n=$((n + 1)); echo "$n" > "{count}"\n'
        f'  [ "$n" -gt {init_failures} ] || exit 1\n'
        "fi\n"
        "exit 0\n"
    )
    dapr.chmod(0o755)
    env = {
        "PATH": f"{bindir}:/usr/bin:/bin",
        "DAPR_INIT_ATTEMPTS": str(attempts),
        "DAPR_INIT_RETRY_DELAY": "0",
    }
    if ci:
        env["CI"] = "true"
    result = subprocess.run(
        ["bash", "-c", f'set -euo pipefail; source "{HELPER}"; dapr_init_with_retry'],
        env=env, capture_output=True, text=True,
    )
    made = calls.read_text().splitlines() if calls.exists() else []
    return result, made


def test_succeeds_first_time_without_cleanup(tmp_path):
    result, calls = run(tmp_path, init_failures=0)
    assert result.returncode == 0
    assert calls == ["dapr init"]


def test_retries_in_ci_after_cleaning_up(tmp_path):
    result, calls = run(tmp_path, init_failures=2)
    assert result.returncode == 0, result.stderr
    assert calls == ["dapr init", "dapr uninstall --all", "dapr init", "dapr uninstall --all", "dapr init"]
    assert "attempt 1 of 3" in result.stderr


def test_gives_up_after_the_last_attempt(tmp_path):
    result, calls = run(tmp_path, init_failures=5)
    assert result.returncode == 1
    assert calls.count("dapr init") == 3
    # The workflow's pre-test step reports the first line that starts with "ERROR:".
    assert "ERROR: dapr init failed 3 times." in result.stderr


def test_does_not_retry_outside_ci(tmp_path):
    result, calls = run(tmp_path, init_failures=1, ci=False)
    assert result.returncode == 1
    assert calls == ["dapr init"], "must not run 'dapr uninstall --all' on a developer machine"
    assert "Not retrying outside CI" in result.stderr


@pytest.mark.parametrize("script", SETUP_SCRIPTS)
def test_setup_scripts_use_the_retry(script):
    text = (REPO / "tools" / "track-tester" / "ci" / script).read_text()
    assert 'source "$REPO_ROOT/tools/track-tester/ci/dapr-init.sh"' in text
    assert "dapr_init_with_retry" in text
    assert "\n  dapr init\n" not in text
