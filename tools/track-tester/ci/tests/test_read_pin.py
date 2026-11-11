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
        'variable "dapr_cli_version" {\n  default = "1.18.2"\n}\n'
        'variable "dapr_cli_version_old" {\n  default = "1.0.0"\n}\n'
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


def test_brace_in_string_before_default(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "x" {\n  description = "uses ${var.x} here"\n  default = "ok"\n}\n')
    assert read_pin(str(f), "x") == "ok"


def test_nested_block_before_default(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text(
        'variable "x" {\n  validation {\n    condition = true\n    default = "inner"\n  }\n'
        '  default = "outer"\n}\n'
    )
    assert read_pin(str(f), "x") == "outer"


def test_ignores_block_commented_out(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('/* variable "d" {\n  default = "old"\n} */\nvariable "d" {\n  default = "new"\n}\n')
    assert read_pin(str(f), "d") == "new"


def test_block_without_default_exits_1(tmp_path):
    f = tmp_path / "v.hcl"
    f.write_text('variable "x" {\n  description = "d"\n}\n')
    r = run_cli(f, "x")
    assert r.returncode == 1
    assert f"ERROR: pin 'x' has no default in {f}" in r.stderr


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
        "code_server_version",
        "dev_dashboard_version",
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


RENDER = REPO / "modules" / "dapr-sandbox" / "scripts" / "render-image-script.sh"


def test_render_image_script_inlines_pins():
    r = subprocess.run(["bash", str(RENDER)], capture_output=True, text=True)
    assert r.returncode == 0, r.stderr
    out = r.stdout
    assert out.startswith("#!/usr/bin/env bash\n")
    assert f"export DAPR_CLI_VERSION={read_pin(str(REPO / "modules" / "dapr-sandbox" / "versions.hcl"), "dapr_cli_version")}" in out
    assert "export NODE_MAJOR=24" in out
    module_pins = str(REPO / "modules" / "dapr-sandbox" / "versions.hcl")
    assert f"export CODE_SERVER_VERSION={read_pin(module_pins, 'code_server_version')}" in out
    assert f"export DEV_DASHBOARD_VERSION={read_pin(module_pins, 'dev_dashboard_version')}" in out
    assert str(REPO) not in out, "output must be self-contained (no repo paths)"
    syntax = subprocess.run(["bash", "-n"], input=out, capture_output=True, text=True)
    assert syntax.returncode == 0, syntax.stderr


def test_prewarm_runtime_pin_matches_lab_runtime_pin():
    module_pin = read_pin(
        str(REPO / "modules" / "dapr-sandbox" / "versions.hcl"),
        "prewarm_dapr_runtime_version",
    )
    lab_pin = read_pin(str(REPO / "dapr-secrets" / "versions.hcl"), "dapr_runtime_version")
    assert module_pin == lab_pin
