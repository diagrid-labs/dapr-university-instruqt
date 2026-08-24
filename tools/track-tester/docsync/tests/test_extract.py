from check_doc_sync import extract_run_commands, Command


def test_language_agnostic_run_block():
    md = """
Intro text.

```bash,run
dapr run --app-id myapp --dapr-http-port 3500
```

Not runnable, ignored:

```text,nocopy
some expected output
```
"""
    cmds = extract_run_commands(md)
    assert cmds == [Command(text="dapr run --app-id myapp --dapr-http-port 3500", lang=None)]


def test_language_details_blocks_are_tagged():
    md = """
<details>
   <summary><b>Run the .NET apps</b></summary>

```bash,run,copy
dotnet build csharp/http/checkout
dotnet build csharp/http/order-processor
```
</details>

<details>
   <summary><b>Run the Python apps</b></summary>

```bash,run,copy
cd python/http
```
</details>
"""
    cmds = extract_run_commands(md)
    assert cmds == [
        Command(text="dotnet build csharp/http/checkout", lang="dotnet"),
        Command(text="dotnet build csharp/http/order-processor", lang="dotnet"),
        Command(text="cd python/http", lang="python"),
    ]


def test_non_run_fences_are_ignored():
    md = """
```bash,nocopy
version: 1
```

```yaml,nocopy
kind: Component
```
"""
    assert extract_run_commands(md) == []


def test_javascript_summary_not_matched_as_java():
    md = """
<details>
   <summary><b>Run the JavaScript apps</b></summary>

```bash,run,copy
npm start
```
</details>
"""
    cmds = extract_run_commands(md)
    assert cmds == [Command(text="npm start", lang="javascript")]


def test_comment_lines_inside_run_fence_are_skipped():
    md = """
```bash,run
# a comment
dapr run --app-id myapp
```
"""
    cmds = extract_run_commands(md)
    assert cmds == [Command(text="dapr run --app-id myapp", lang=None)]
