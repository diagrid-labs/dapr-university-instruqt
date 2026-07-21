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
