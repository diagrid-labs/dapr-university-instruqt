"""A heredoc Run block (`cat > <file> <<'EOF'` ... `EOF`) is ONE runnable command whose body is
kept verbatim, including blank lines and `#` lines such as `#:package ...`. It is covered when the
whole text appears in the suite (or another coverage file), also as a `# doc-sync coverage` comment
block with one `#` in front of each line."""
import check_doc_sync as ds
from check_doc_sync import Command

BODY = """#:package Aspire.Hosting.AppHost@17.0.0

using CommunityToolkit.Aspire.Hosting.Dapr;
var builder = DistributedApplication.CreateBuilder(args);"""

MD = f"""
```bash,run
cd /root/university-labs/workflow-aspire
```

```bash,run
cat > MeridianDiagnostics/apphost.cs <<'EOF'
{BODY}
EOF
```

```bash,run
aspire run
```
"""

HEREDOC = f"cat > MeridianDiagnostics/apphost.cs <<'EOF'\n{BODY}\nEOF"


def test_heredoc_run_block_is_one_command():
    assert ds.extract_run_commands(MD) == [
        Command(text="cd /root/university-labs/workflow-aspire", lang=None),
        Command(text=HEREDOC, lang=None),
        Command(text="aspire run", lang=None),
    ]


def test_here_string_is_not_a_heredoc():
    md = "```bash,run\nread -r a <<<\"$x\"\necho b\n```\n"
    assert [c.text for c in ds.extract_run_commands(md)] == ['read -r a <<<"$x"', "echo b"]


def test_heredoc_covered_by_its_full_text_in_the_suite():
    suite = f"Run    bash -c '{HEREDOC}'\naspire run\ncd /root/university-labs/workflow-aspire\n"
    assert ds.find_uncovered(ds.extract_run_commands(MD), suite) == []


def test_heredoc_covered_by_a_commented_coverage_block():
    commented = "\n".join(f"#   {line}" if line else "#" for line in HEREDOC.splitlines())
    suite = f"aspire run\n# doc-sync coverage:\n#   cd /root/university-labs/workflow-aspire\n{commented}\n"
    assert ds.find_uncovered(ds.extract_run_commands(MD), suite) == []


def test_heredoc_with_a_changed_body_line_is_uncovered():
    stale = HEREDOC.replace("Aspire.Hosting.AppHost@17.0.0", "Aspire.Hosting.AppHost@13.4.0")
    suite = f"aspire run\ncd /root/university-labs/workflow-aspire\n{stale}\n"
    assert [c.text for c in ds.find_uncovered(ds.extract_run_commands(MD), suite)] == [HEREDOC]


def test_heredoc_body_lines_alone_do_not_cover_it():
    # Only the body lines, without the `cat > ... <<'EOF'` line: the command itself is missing.
    suite = f"aspire run\ncd /root/university-labs/workflow-aspire\n{BODY}\nEOF\n"
    assert [c.text for c in ds.find_uncovered(ds.extract_run_commands(MD), suite)] == [HEREDOC]


def test_unterminated_heredoc_ends_at_the_closing_fence():
    md = "```bash,run\ncat > f <<'EOF'\nx\n```\n\n```bash,run\necho next\n```\n"
    assert [c.text for c in ds.extract_run_commands(md)] == ["cat > f <<'EOF'\nx", "echo next"]
