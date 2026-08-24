import textwrap

import check_doc_sync as ds
from check_doc_sync import Command


def test_normalize_collapses_whitespace():
    assert ds.normalize("  dapr   run   -f  . ") == "dapr run -f ."


def test_find_uncovered_reports_missing_only():
    cmds = [
        Command(text="dapr run -f .", lang="python"),
        Command(text="npm install", lang="javascript"),
    ]
    haystack = "Run Multi-App    dapr run -f ."  # only the first appears
    uncovered = ds.find_uncovered(cmds, haystack)
    assert [c.text for c in uncovered] == ["npm install"]


def test_main_passes_when_all_covered(tmp_path, capsys):
    md = tmp_path / "assignment.md"
    md.write_text(textwrap.dedent("""
        ```bash,run
        dapr init
        ```
    """))
    robot = tmp_path / "challenge.robot"
    robot.write_text("Some Keyword    dapr init\n")
    assert ds.main([str(md), str(robot)]) == 0


def test_main_fails_and_lists_uncovered(tmp_path, capsys):
    md = tmp_path / "assignment.md"
    md.write_text(textwrap.dedent("""
        ```bash,run
        dapr uninstall --all
        ```
    """))
    robot = tmp_path / "challenge.robot"
    robot.write_text("Some Keyword    dapr init\n")
    assert ds.main([str(md), str(robot)]) == 1
    assert "dapr uninstall --all" in capsys.readouterr().out


def test_main_usage_error_returns_2():
    assert ds.main([]) == 2
