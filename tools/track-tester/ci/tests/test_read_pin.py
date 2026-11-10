import subprocess
import sys
from pathlib import Path

import pytest

from read_pin import read_pin

CLI = Path(__file__).resolve().parents[1] / "read_pin.py"
REPO = Path(__file__).resolve().parents[4]


def run_cli(path, name):
    return subprocess.run(
        [sys.executable, str(CLI), str(path), name],
        capture_output=True,
        text=True,
    )


def test_reads_default_of_variable_block(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "dapr_runtime_version" {\n  default = "1.18.7"\n}\n')
    assert read_pin(str(f), "dapr_runtime_version") == "1.18.7"


def test_tolerates_fmt_alignment_and_description(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "x" {\n  description = "d"\n  default     = "a.b"\n}\n')
    assert read_pin(str(f), "x") == "a.b"


def test_does_not_match_name_prefix(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text(
        'variable "dapr_cli_version_old" {\n  default = "1.0.0"\n}\n'
        'variable "dapr_cli_version" {\n  default = "1.18.2"\n}\n'
    )
    assert read_pin(str(f), "dapr_cli_version") == "1.18.2"


def test_ignores_commented_out_block(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text(
        '# variable "x" {\n#   default = "old"\n# }\n'
        '// variable "x" {\n//   default = "older"\n// }\n'
        'variable "x" {\n  default = "new"\n}\n'
    )
    assert read_pin(str(f), "x") == "new"


def test_missing_pin_exits_1_with_error(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "y" {\n  default = "1"\n}\n')
    r = run_cli(f, "x")
    assert r.returncode == 1
    assert r.stdout == ""
    assert "not found" in r.stderr
    assert f"ERROR: pin 'x' not found in {f}" in r.stderr


def test_duplicate_pin_exits_1_with_error(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text(
        'variable "x" {\n  default = "1"\n}\nvariable "x" {\n  default = "2"\n}\n'
    )
    r = run_cli(f, "x")
    assert r.returncode == 1
    assert "more than once" in r.stderr


def test_cli_prints_value_and_newline_only(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "x" {\n  default = "1.2.3"\n}\n')
    r = run_cli(f, "x")
    assert r.returncode == 0
    assert r.stdout == "1.2.3\n"


REAL_PINS = {
    "modules/dapr-sandbox/versions.hcl": [
        "dotnet_sdk_channel",
        "java_version",
        "node_major",
        "dapr_cli_version",
        "image_ref",
    ],
    "dapr-secrets/versions.hcl": ["dapr_runtime_version", "tracks_src_ref"],
}


@pytest.mark.parametrize("rel", sorted(REAL_PINS))
def test_reads_real_repo_files(rel):
    path = REPO / rel
    if not path.exists():
        pytest.skip(f"{rel} not created yet")
    for name in REAL_PINS[rel]:
        assert read_pin(str(path), name)
