"""dapr-workflow-aspire pins: each lives once, in dapr-workflow-aspire/versions.hcl, and everything
else reads it there (the module through lab_environment, the CI setup script and the harness
variables through read_pin.py). The pages repeat the Aspire version; Task 4 adds the test that
they match the pin, once page 1 has content."""
import importlib
import re
from pathlib import Path

from read_pin import read_pin

ROOT = Path(__file__).resolve().parents[4]
LAB = ROOT / "dapr-workflow-aspire"
VERSIONS = LAB / "versions.hcl"
SETUP_CI = ROOT / "tools" / "track-tester" / "ci" / "setup-dapr-workflow-aspire.sh"
WORKFLOW = ROOT / ".github" / "workflows" / "test-dapr-workflow-aspire.yml"
VARIABLES = ROOT / "tools" / "track-tester" / "variables" / "dapr_workflow_aspire.py"


def _hcl():
    return " ".join(VERSIONS.read_text().split())


def test_aspire_cli_pin():
    assert read_pin(str(VERSIONS), "aspire_cli_version") == "17.0.0"


def test_dapr_runtime_pin():
    assert read_pin(str(VERSIONS), "dapr_runtime_version") == "1.19.2"


def test_tracks_src_ref_is_a_full_commit_sha():
    assert re.fullmatch(r"[0-9a-f]{40}", read_pin(str(VERSIONS), "tracks_src_ref"))


def test_module_version_is_3_2_0():
    assert 'source = "diagrid/dapr-sandbox" version = "3.2.0"' in _hcl()


def test_module_inputs():
    hcl = _hcl()
    assert 'editor_folder = "workflow-aspire"' in hcl
    assert 'lab_startup_script = file("scripts/lab-setup.sh")' in hcl
    # lab-setup.sh reads the Aspire pin as $LAB_ASPIRE_CLI_VERSION (risk 6: lab_environment reaches
    # it). Not ASPIRE_CLI_VERSION: the Aspire CLI reads that name as an identity override.
    assert "lab_environment = { LAB_ASPIRE_CLI_VERSION = variable.aspire_cli_version }" in hcl


def test_aspire_cli_version_is_never_exported():
    # The Aspire 17 CLI treats an ASPIRE_CLI_VERSION environment variable as an identity override
    # ("Aspire CLI is emulating identity 'stable' version ...") on every command.
    assert "ASPIRE_CLI_VERSION =" not in _hcl().replace("LAB_ASPIRE_CLI_VERSION =", "")
    for path in (SETUP_CI, WORKFLOW):
        text = path.read_text().replace("LAB_ASPIRE_CLI_VERSION", "")
        assert "ASPIRE_CLI_VERSION=" not in text, path


def test_ci_setup_reads_the_aspire_pin():
    text = SETUP_CI.read_text()
    assert re.search(r'"\$READ_PIN" "\$LAB_DIR/versions\.hcl" aspire_cli_version', text)
    assert re.search(r"--version\s+\"\$LAB_ASPIRE_CLI_VERSION\"", text)


def test_no_second_copy_of_the_aspire_pin():
    pin = read_pin(str(VERSIONS), "aspire_cli_version")
    for path in (SETUP_CI, WORKFLOW, VARIABLES, LAB / "scripts" / "lab-setup.sh"):
        assert pin not in path.read_text(), f"{path} repeats the Aspire pin; read it with read_pin.py"


def test_variables_read_the_aspire_pin():
    mod = importlib.import_module("dapr_workflow_aspire")
    assert mod.ASPIRE_CLI_VERSION == read_pin(str(VERSIONS), "aspire_cli_version")
