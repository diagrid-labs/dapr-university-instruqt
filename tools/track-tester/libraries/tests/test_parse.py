import pytest
from assignment_blocks import (
    Block,
    parse_blocks,
    is_run_block,
    is_writable_block,
    command_lines,
    dest_for_block,
    resolve_files,
    UnmappedBlockError,
)

MD = """
Intro.

```shell,run
dotnet new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics
```

```shell,run,copy
cd EnterpriseDiagnostics
```

```json,copy
{ "$schema": "https://json.schemastore.org/launchsettings.json" }
```

```text,nocopy
display only, ignored
```
"""


def test_parse_captures_lang_tags_body():
    blocks = parse_blocks(MD)
    assert [(b.lang, b.tags) for b in blocks] == [
        ("shell", ("run",)),
        ("shell", ("run", "copy")),
        ("json", ("copy",)),
        ("text", ("nocopy",)),
    ]
    assert blocks[0].body == "dotnet new aspire-starter -n EnterpriseDiagnostics -o EnterpriseDiagnostics"


def test_classification():
    blocks = parse_blocks(MD)
    assert [is_run_block(b) for b in blocks] == [True, True, False, False]
    assert [is_writable_block(b) for b in blocks] == [False, False, True, False]


def test_command_lines_joins_continuations_and_drops_comments():
    body = "# a comment\ndocker run -p 1:1 \\\n  -e X=y \\\n  image\n\ntouch f"
    assert command_lines(body) == ["docker run -p 1:1 -e X=y image", "touch f"]


def test_resolve_files_maps_by_anchor():
    blocks = parse_blocks(MD)
    manifest = [('"$schema": "https://json.schemastore.org/launchsettings.json"',
                 "AppHost/Properties/launchSettings.json", "write")]
    resolved = resolve_files(blocks, manifest)
    assert len(resolved) == 1
    dest, mode, body = resolved[0]
    assert dest == "AppHost/Properties/launchSettings.json"
    assert mode == "write"
    assert "$schema" in body


def test_resolve_files_raises_on_unmapped_block():
    blocks = parse_blocks("```csharp,copy\nclass Orphan {}\n```")
    with pytest.raises(UnmappedBlockError):
        resolve_files(blocks, [])


def test_resolve_files_raises_when_anchor_matches_nothing():
    blocks = parse_blocks(MD)
    manifest = [
        ('"$schema": "https://json.schemastore.org/launchsettings.json"',
         "AppHost/Properties/launchSettings.json", "write"),
        ("anchor that is absent", "nowhere.cs", "write"),
    ]
    with pytest.raises(UnmappedBlockError):
        resolve_files(blocks, manifest)
