"""A Run block that writes a file with a heredoc (`cat > <file> <<'EOF'` ... `EOF`) is ONE command:
its body is kept verbatim (blank lines, `#` lines such as `#:package ...`, indentation) and is never
run line by line. dapr-workflow-aspire writes its plumbing files this way."""
from assignment_blocks import AssignmentBlocks, command_lines, is_run_block, parse_blocks

HEREDOC_BODY = """#:package Aspire.Hosting.AppHost@17.0.0
#:package CommunityToolkit.Aspire.Hosting.Dapr@13.0.0

using CommunityToolkit.Aspire.Hosting.Dapr;

var builder = DistributedApplication.CreateBuilder(args);
    // indented comment, kept as is
builder.Build().Run();"""

MD = f"""# Page

```bash,run
cd sub
```

```bash,run
cat > apphost.cs <<'EOF'
{HEREDOC_BODY}
EOF
```

```bash,run
echo after > after.txt
```
"""


def test_heredoc_run_block_is_one_command():
    body = f"cat > apphost.cs <<'EOF'\n{HEREDOC_BODY}\nEOF\necho next"
    assert command_lines(body) == [f"cat > apphost.cs <<'EOF'\n{HEREDOC_BODY}\nEOF", "echo next"]


def test_heredoc_variants_unquoted_double_quoted_and_dash():
    for opener, end in [("<<EOF", "EOF"), ('<< "END"', "END"), ("<<-EOF", "\tEOF")]:
        body = f"cat > f {opener}\n# kept\n\n  x\n{end}"
        assert command_lines(body) == [body], opener


def test_here_string_is_not_a_heredoc():
    assert command_lines("read -r a <<<\"$x\"\necho b") == ['read -r a <<<"$x"', "echo b"]


def test_heredoc_body_written_verbatim(tmp_path):
    (tmp_path / "sub").mkdir()
    md = tmp_path / "assignment.md"
    md.write_text(MD)
    AssignmentBlocks().apply_challenge(str(md), str(tmp_path), str(tmp_path), [])
    assert (tmp_path / "sub" / "apphost.cs").read_text() == HEREDOC_BODY + "\n"
    assert (tmp_path / "sub" / "after.txt").read_text() == "after\n"


def test_bash_run_blocks_are_run_blocks():
    kinds = [(b.lang, is_run_block(b)) for b in parse_blocks(
        "```bash,run\nls\n```\n\n```shell,run\nls\n```\n\n```bash\nls\n```\n\n```csharp,copy\nx\n```\n")]
    assert kinds == [("bash", True), ("shell", True), ("bash", False), ("csharp", False)]


def test_get_command_containing_returns_the_whole_heredoc(tmp_path):
    md = tmp_path / "assignment.md"
    md.write_text(MD)
    cmd = AssignmentBlocks().get_command_containing(str(md), "cat > apphost.cs")
    assert cmd == f"cat > apphost.cs <<'EOF'\n{HEREDOC_BODY}\nEOF"
