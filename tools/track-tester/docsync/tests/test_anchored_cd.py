import textwrap

import check_doc_sync as ds
from check_doc_sync import Command

ROOT = "cd /root/ai-agent-tracks-instruqt/secrets"


def test_relative_cd_without_an_anchor_is_reported():
    cmds = [Command(text="cd dotnet/Demo1-ReadSecret", lang="dotnet")]
    assert ds.find_unanchored_cds(cmds) == cmds


def test_relative_cd_after_an_absolute_cd_passes():
    cmds = [
        Command(text=ROOT, lang=None),
        Command(text="cd dotnet/Demo1-ReadSecret", lang="dotnet"),
        Command(text="cd python/Demo1-ReadSecret", lang="python"),
    ]
    assert ds.find_unanchored_cds(cmds) == []


def test_relative_cd_before_the_anchor_is_still_reported():
    early = Command(text="cd dotnet/Demo1-ReadSecret", lang="dotnet")
    cmds = [early, Command(text=ROOT, lang=None)]
    assert ds.find_unanchored_cds(cmds) == [early]


def test_anchor_and_relative_cd_in_one_chain_pass():
    cmds = [Command(text=f"{ROOT} && cd nested-demo", lang=None)]
    assert ds.find_unanchored_cds(cmds) == []


def test_relative_cd_inside_a_chain_is_reported():
    cmds = [Command(text="dapr stop -f . && cd python/Demo2-Scoping", lang="python")]
    assert ds.find_unanchored_cds(cmds) == cmds


def test_home_variable_and_bare_cds_count_as_absolute():
    cmds = [
        Command(text="cd ~/ai-agent-tracks-instruqt/secrets", lang=None),
        Command(text="cd $HOME/secrets", lang=None),
        Command(text="cd", lang=None),
    ]
    assert ds.find_unanchored_cds(cmds) == []


def test_non_cd_commands_are_ignored():
    cmds = [
        Command(text="dapr run -f .", lang=None),
        Command(text="curl -s http://localhost:5001/secret/abcd", lang=None),
    ]
    assert ds.find_unanchored_cds(cmds) == []


def _write(tmp_path, *cd_targets):
    blocks = "".join(f"```bash,run\ncd {t}\n```\n\n" for t in cd_targets)
    md = tmp_path / "assignment.md"
    md.write_text(textwrap.dedent(blocks))
    robot = tmp_path / "challenge.robot"
    robot.write_text("".join(f"#   cd {t}\n" for t in cd_targets))
    return str(md), str(robot)


def test_main_flag_fails_on_unanchored_cd(tmp_path, capsys):
    md, robot = _write(tmp_path, "dotnet/Demo1-ReadSecret")
    assert ds.main(["--require-anchored-cd", md, robot]) == 1
    assert "cd dotnet/Demo1-ReadSecret" in capsys.readouterr().out


def test_main_flag_passes_on_anchored_cd(tmp_path):
    md, robot = _write(tmp_path, "/root/repo", "dotnet/Demo1-ReadSecret")
    assert ds.main(["--require-anchored-cd", md, robot]) == 0


def test_main_without_flag_allows_unanchored_cd(tmp_path):
    md, robot = _write(tmp_path, "dotnet/Demo1-ReadSecret")
    assert ds.main([md, robot]) == 0
