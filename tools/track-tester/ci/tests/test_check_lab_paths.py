import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import check_lab_paths as c  # noqa: E402


def write(root, name, text):
    p = root / name
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text)


def test_all_present_passes(tmp_path):
    write(tmp_path, "a.hcl", 'x = "${file("scripts/a.sh")}"\ntask {\n  script = "s/b.sh"\n}\npage "p" {\n  file = "1/a.md"\n}\n')
    for f in ("scripts/a.sh", "s/b.sh", "1/a.md"):
        write(tmp_path, f, "")
    assert c.main(["x", str(tmp_path)]) == 0


def test_missing_files_listed(tmp_path, capsys):
    write(tmp_path, "a.hcl", 'x = file("scripts/gone.sh")\ny {\n  script = "s/gone2.sh"\n  file   = "gone3.md"\n}\n')
    assert c.main(["x", str(tmp_path)]) == 1
    err = capsys.readouterr().err
    for name in ("scripts/gone.sh", "s/gone2.sh", "gone3.md"):
        assert name in err


def test_ignores_comments_escaped_and_startup_script(tmp_path):
    write(
        tmp_path,
        "a.hcl",
        '# file("nope.sh")\n// script = "nope2.sh"\n'
        'description = "pass file(\\"scripts/x.sh\\") here"\n'
        'startup_script = "#!/bin/bash"\n',
    )
    assert c.main(["x", str(tmp_path)]) == 0


def test_bad_usage_and_dir():
    assert c.main(["x"]) == 2
    assert c.main(["x", "/no/such/dir"]) == 2
