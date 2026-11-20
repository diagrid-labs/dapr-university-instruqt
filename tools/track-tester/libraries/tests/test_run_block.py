import pytest

from assignment_blocks import AssignmentBlocks

MD = """# Page

```bash,run
cd /root/x
```

```bash,run
docker rm -f db >/dev/null 2>&1 || true
docker run -d --name db \\
  postgres:18.7
```

```text,nocopy
docker run -d --name db (not runnable)
```
"""


def test_returns_the_whole_run_block_containing_the_needle(tmp_path):
    md = tmp_path / "assignment.md"
    md.write_text(MD)
    body = AssignmentBlocks().get_run_block_containing(str(md), "docker run -d --name db")
    assert body == "docker rm -f db >/dev/null 2>&1 || true\ndocker run -d --name db \\\n  postgres:18.7"


def test_ignores_blocks_that_are_not_runnable(tmp_path):
    md = tmp_path / "assignment.md"
    md.write_text(MD)
    with pytest.raises(ValueError, match="not runnable"):
        AssignmentBlocks().get_run_block_containing(str(md), "not runnable")
