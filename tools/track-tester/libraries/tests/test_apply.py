import os
import pytest
from assignment_blocks import AssignmentBlocks, UnmappedBlockError

SYNTH = """
```shell,run
mkdir sub
```

```csharp,copy
// ANCHOR-FOO
class Foo {}
```

```shell,run,copy
cd sub
```

```shell,run
touch made-in-sub.txt
```

```shell,run
aspire run
```
"""


def _write_md(tmp_path, text):
    p = tmp_path / "assignment.md"
    p.write_text(text)
    return str(p)


def test_apply_writes_files_runs_commands_tracks_cd_and_skips(tmp_path):
    md = _write_md(tmp_path, SYNTH)
    manifest = [("ANCHOR-FOO", "sub/Foo.cs", "write")]
    AssignmentBlocks().apply_challenge(md, str(tmp_path), str(tmp_path), manifest)
    # mkdir ran, file written under solution_dir
    assert (tmp_path / "sub" / "Foo.cs").read_text().strip().endswith("class Foo {}")
    # `cd sub` was honoured: touch created the file inside sub/
    assert (tmp_path / "sub" / "made-in-sub.txt").exists()
    # `aspire run` was skipped (no error, nothing to assert beyond no crash)


def test_apply_raises_on_unmapped_block(tmp_path):
    md = _write_md(tmp_path, "```csharp,copy\nclass Orphan {}\n```")
    with pytest.raises(UnmappedBlockError):
        AssignmentBlocks().apply_challenge(md, str(tmp_path), str(tmp_path), [])


def test_get_command_containing(tmp_path):
    md = _write_md(tmp_path, SYNTH)
    assert AssignmentBlocks().get_command_containing(md, "aspire run") == "aspire run"
    with pytest.raises(ValueError):
        AssignmentBlocks().get_command_containing(md, "no-such-command")
