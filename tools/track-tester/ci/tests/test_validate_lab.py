import shutil
import subprocess
from pathlib import Path

import pytest

SCRIPT = Path(__file__).resolve().parents[1] / "validate-lab.sh"

pytestmark = pytest.mark.skipif(shutil.which("instruqt") is None, reason="instruqt CLI not installed")

MODULE = """\
variable "cpu" {
  default = 2
}

resource "vm" "sandbox" {
  image {
    name = "ubuntu:24.04"
  }

  resources {
    cpu    = variable.cpu
    memory = 2048
  }
}

output "vm" {
  value = resource.vm.sandbox
}
"""

LAB = """\
module "sandbox" {
  source  = "%s"
  version = "1.0.0"
}

resource "terminal" "cli" {
  target = module.sandbox.output.vm
}

resource "layout" "main" {
  column {
    instructions {}
  }

  column {
    tab "cli" {
      target = resource.terminal.cli
      title  = "CLI"
    }
  }
}
"""


def make(tmp_path, source):
    lab = tmp_path / "lab"
    mod = tmp_path / "mod"
    lab.mkdir()
    mod.mkdir()
    (lab / "main.hcl").write_text(LAB % source)
    (mod / "main.hcl").write_text(MODULE)
    return lab, mod


def run(lab, mod):
    return subprocess.run([str(SCRIPT), str(lab), str(mod)], capture_output=True, text=True)


def test_valid_fixture_passes(tmp_path):
    lab, mod = make(tmp_path, "diagrid/dapr-sandbox")
    r = run(lab, mod)
    assert r.returncode == 0, r.stdout + r.stderr
    # original lab is untouched
    assert "diagrid/dapr-sandbox" in (lab / "main.hcl").read_text()


def test_missing_expected_source_fails_clearly(tmp_path):
    lab, mod = make(tmp_path, "someone/else")
    r = run(lab, mod)
    assert r.returncode != 0
    assert 'source = "diagrid/dapr-sandbox"' in r.stderr


def test_reordered_unspaced_attributes_pass(tmp_path):
    lab, mod = make(tmp_path, "diagrid/dapr-sandbox")
    (lab / "main.hcl").write_text(
        (lab / "main.hcl").read_text().replace(
            'source  = "diagrid/dapr-sandbox"\n  version = "1.0.0"',
            'version="1.0.0"\n  source="diagrid/dapr-sandbox"',
        )
    )
    assert 'version="1.0.0"' in (lab / "main.hcl").read_text()
    r = run(lab, mod)
    assert r.returncode == 0, r.stdout + r.stderr


def test_incomplete_rewrite_fails_clearly(tmp_path):
    lab, mod = make(tmp_path, "diagrid/dapr-sandbox")
    # One-line block: the rewrite's version-line removal cannot match it.
    text = (lab / "main.hcl").read_text().replace(
        'module "sandbox" {\n  source  = "diagrid/dapr-sandbox"\n  version = "1.0.0"\n}',
        'module "sandbox" { source = "diagrid/dapr-sandbox"\n  version = "1.0.0" }\n',
    )
    (lab / "main.hcl").write_text(text)
    r = run(lab, mod)
    assert r.returncode != 0
    assert "rewrite incomplete" in r.stderr
