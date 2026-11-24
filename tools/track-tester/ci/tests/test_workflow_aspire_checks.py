"""Run the dapr-workflow-aspire page check scripts against temporary workspaces.

Each page ends with an Instruqt task (tasks.hcl) whose conditions run read-only scripts in
`<page>/scripts/check-*.sh`. The scripts read the workspace at /root/university-labs/workflow-aspire,
or at $WORKSPACE when it is set, which is how these tests point them at a fixture. Each page task
appends its own section to this file.
"""
import os
import re
import subprocess
from pathlib import Path

import pytest

LAB = Path(__file__).resolve().parents[4] / "dapr-workflow-aspire"


def run(script, workspace):
    r = subprocess.run(["bash", str(script)], env={**os.environ, "WORKSPACE": str(workspace)},
                       capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout + r.stderr


def snapshot(root):
    """Every path under root with its content (files) or None (folders): a check never writes."""
    return {str(p.relative_to(root)): (p.read_bytes() if p.is_file() else None)
            for p in sorted(root.rglob("*"))}


def task_block(task_id):
    text = (LAB / "tasks.hcl").read_text()
    m = re.search(r'resource "task" "%s" \{(.*?)\n\}' % task_id, text, re.S)
    assert m, f"no task {task_id} in tasks.hcl"
    return m.group(1)


def conditions(task_id):
    """(condition name, script, failure_message) for every condition of a task."""
    return re.findall(
        r'condition "([a-z_]+)" \{.*?script\s*=\s*"([^"]+)"\s*failure_message\s*=\s*"([^"]+)"',
        task_block(task_id), re.S)


# ---- Page 1: create the solution ---------------------------------------------------------------
P1 = LAB / "1-create-the-solution" / "scripts"
P1_CHECKS = ("solution", "engineering", "dapr-workflow", "launch-profile")

CSPROJ = """<Project Sdk="Microsoft.NET.Sdk.Web">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
  </PropertyGroup>
{refs}
</Project>
"""
DAPR_REF = """
  <ItemGroup>
    <PackageReference Include="Dapr.Workflow" Version="1.19.1" />
  </ItemGroup>
"""
RUN_JSON = """{
  "profiles": {
    "http": {
      "commandName": "Project",
      "applicationUrl": "%s",
      "environmentVariables": {
        "ASPIRE_RESOURCE_SERVICE_ENDPOINT_URL": "http://localhost:17003"
      }
    }
  }
}
"""


def page1_workspace(root, apphost=True, csproj=True, dapr=True, url="http://0.0.0.0:17000"):
    """The workspace as page 1 leaves it; each flag removes or changes one part."""
    sol = root / "MeridianDiagnostics"
    sol.mkdir(parents=True)
    if apphost:
        (sol / "apphost.cs").write_text("#:package Aspire.Hosting.AppHost@17.0.0\n")
    if csproj:
        (sol / "Engineering").mkdir()
        (sol / "Engineering" / "Engineering.csproj").write_text(CSPROJ.format(refs=DAPR_REF if dapr else ""))
    if url is not None:
        (sol / "apphost.run.json").write_text(RUN_JSON % url)
    return root


def p1(name, workspace):
    return run(P1 / f"check-{name}.sh", workspace)


def test_page1_all_checks_pass(tmp_path):
    ws = page1_workspace(tmp_path)
    before = snapshot(ws)
    for name in P1_CHECKS:
        rc, out = p1(name, ws)
        assert rc == 0, f"{name}: {out}"
    assert snapshot(ws) == before, "a page 1 check changed the workspace"


def test_page1_empty_workspace_fails_every_check_that_owns_a_file(tmp_path):
    for name in ("solution", "engineering", "launch-profile"):
        assert p1(name, tmp_path)[0] != 0, name


def test_page1_missing_workspace_fails(tmp_path):
    rc, out = p1("solution", tmp_path / "nowhere")
    assert rc != 0
    assert "apphost.cs" in out


def test_page1_solution_fails_without_apphost(tmp_path):
    rc, out = p1("solution", page1_workspace(tmp_path, apphost=False))
    assert rc != 0
    assert "apphost.cs" in out


def test_page1_engineering_fails_without_the_project(tmp_path):
    rc, out = p1("engineering", page1_workspace(tmp_path, csproj=False))
    assert rc != 0
    assert "Engineering.csproj" in out


def test_page1_dapr_workflow_fails_without_the_package(tmp_path):
    rc, out = p1("dapr-workflow", page1_workspace(tmp_path, dapr=False))
    assert rc != 0
    assert "Dapr.Workflow" in out


def test_page1_dapr_workflow_leaves_a_missing_project_to_the_engineering_check(tmp_path):
    # Only the engineering condition reports a missing project, so the learner sees one hint.
    assert p1("dapr-workflow", page1_workspace(tmp_path, csproj=False))[0] == 0


@pytest.mark.parametrize("url", ["http://localhost:15056", "https://localhost:17220;http://localhost:15056",
                                 "http://0.0.0.0:18888"])
def test_page1_launch_profile_fails_on_the_generated_profile(tmp_path, url):
    rc, out = p1("launch-profile", page1_workspace(tmp_path, url=url))
    assert rc != 0
    assert "0.0.0.0:17000" in out


def test_page1_launch_profile_fails_without_the_file(tmp_path):
    rc, out = p1("launch-profile", page1_workspace(tmp_path, url=None))
    assert rc != 0
    assert "apphost.run.json" in out


def test_page1_task_runs_every_check_with_its_own_message():
    conds = conditions("create_solution")
    assert [c[0] for c in conds] == ["solution", "engineering", "dapr_workflow", "launch_profile"]
    scripts = [c[1] for c in conds]
    assert scripts == [f"1-create-the-solution/scripts/check-{n}.sh" for n in P1_CHECKS]
    for _, script, message in conds:
        assert (LAB / script).is_file(), script
        # Each message names the section to redo.
        assert re.search(r"section [2-4]", message), message
    assert len({c[2] for c in conds}) == len(conds), "two conditions share a failure_message"
    assert "solve" not in task_block("create_solution")


def test_page1_lists_its_task():
    pages = (LAB / "pages.hcl").read_text()
    page = re.search(r'resource "page" "create_the_solution" \{(.*?)\n\}', pages, re.S).group(1)
    assert "create_solution = resource.task.create_solution" in page
    md = (LAB / "1-create-the-solution" / "assignment.md").read_text()
    tag = '<instruqt-task id="create_solution"></instruqt-task>'
    assert md.count(tag) == 1
    # The task is the page's last section before the closing `---`.
    assert md.index(tag) < md.rindex("\n---\n")
    assert "## " not in md[md.index(tag):md.rindex("\n---\n")]


# ---- Page 2: write the workflow ----------------------------------------------------------------
P2 = LAB / "2-write-the-workflow" / "scripts"
P2_CHECKS = ("workflow", "activities", "program", "build")

WORKFLOW_CS = "public class DiagnosticsWorkflow : Workflow<DiagnosticsInput, DiagnosticsOutput>\n{\n}\n"
ACTIVITIES_CS = """public class DiagnoseSubsystemActivity : WorkflowActivity<string, SubsystemReport> { }
public class PrioritizeDiagnosticsActivity : WorkflowActivity<SubsystemReport[], string> { }
public class NotifyBridgeActivity : WorkflowActivity<string, bool> { }
"""
PROGRAM_CS = "builder.Services.AddDaprWorkflow(options => { });\n"
TEMPLATE_PROGRAM_CS = 'var app = WebApplication.CreateBuilder(args).Build();\napp.MapGet("/", () => "Hello World!");\napp.Run();\n'

# A stand-in for `dotnet` that records how it was called and fails when FAKE_DOTNET_RC says so,
# printing compiler errors the way `dotnet build` does.
FAKE_DOTNET = """#!/usr/bin/env bash
{ echo "cwd=$PWD"; echo "args=$*"; } >> "$FAKE_DOTNET_LOG"
# The -o folder exists while the build runs.
prev=""; for a in "$@"; do [ "$prev" = "-o" ] && echo "out=$a exists=$([ -d "$a" ] && echo yes || echo no)" >> "$FAKE_DOTNET_LOG"; prev="$a"; done
if [ "${FAKE_DOTNET_RC:-0}" != 0 ]; then
    echo "$PWD/Engineering/Activities.cs(41,2): error CS1513: } expected [$PWD/Engineering/Engineering.csproj]"
    echo "$PWD/Engineering/Activities.cs(41,2): error CS1513: } expected [$PWD/Engineering/Engineering.csproj]"
    echo "Build failed with 2 error(s)"
    exit 1
fi
echo "Build succeeded"
"""


def page2_workspace(root, workflow=WORKFLOW_CS, activities=ACTIVITIES_CS, program=PROGRAM_CS, csproj=True):
    """The workspace as page 2 leaves it; None leaves a file out."""
    eng = root / "MeridianDiagnostics" / "Engineering"
    eng.mkdir(parents=True)
    if csproj:
        (eng / "Engineering.csproj").write_text(CSPROJ.format(refs=DAPR_REF))
    for name, body in (("DiagnosticsWorkflow.cs", workflow), ("Activities.cs", activities), ("Program.cs", program)):
        if body is not None:
            (eng / name).write_text(body)
    return root


@pytest.fixture
def fake_dotnet(tmp_path):
    bin_dir = tmp_path / "fakebin"
    bin_dir.mkdir()
    exe = bin_dir / "dotnet"
    exe.write_text(FAKE_DOTNET)
    exe.chmod(0o755)
    log = tmp_path / "dotnet.log"
    return bin_dir, log


def p2(name, workspace, fake=None, rc=0):
    env = {**os.environ, "WORKSPACE": str(workspace)}
    if fake is not None:
        bin_dir, log = fake
        env.update(PATH=f"{bin_dir}:{env['PATH']}", FAKE_DOTNET_LOG=str(log), FAKE_DOTNET_RC=str(rc))
    r = subprocess.run(["bash", str(P2 / f"check-{name}.sh")], env=env, capture_output=True, text=True,
                       timeout=60)
    return r.returncode, r.stdout + r.stderr


def test_page2_all_checks_pass(tmp_path, fake_dotnet):
    ws = page2_workspace(tmp_path / "ws")
    before = snapshot(ws)
    for name in P2_CHECKS:
        rc, out = p2(name, ws, fake_dotnet)
        assert rc == 0, f"{name}: {out}"
    assert snapshot(ws) == before, "a page 2 check changed the workspace"


def test_page2_build_is_read_only(tmp_path, fake_dotnet):
    # Risk 5: build Engineering without restoring, into a temporary folder that is removed after, so
    # a running `aspire run` keeps its bin/ folder.
    ws = page2_workspace(tmp_path / "ws")
    rc, out = p2("build", ws, fake_dotnet)
    assert rc == 0, out
    log = fake_dotnet[1].read_text().splitlines()
    assert f"cwd={ws / 'MeridianDiagnostics'}" in log
    args = next(line for line in log if line.startswith("args="))
    m = re.fullmatch(r"args=build Engineering --no-restore -o (\S+)", args)
    assert m, args
    out_dir = Path(m.group(1))
    assert f"out={out_dir} exists=yes" in log
    assert not out_dir.exists(), "the build output folder was left behind"


def test_page2_build_fails_and_names_the_file(tmp_path, fake_dotnet):
    ws = page2_workspace(tmp_path / "ws")
    rc, out = p2("build", ws, fake_dotnet, rc=1)
    assert rc != 0
    assert "does not build" in out
    # The file with the errors, once, so the learner knows which paste to compare.
    assert re.search(r"Errors in: Activities\.cs$", out, re.M), out
    out_dir = re.search(r"-o (\S+)", fake_dotnet[1].read_text()).group(1)
    assert not Path(out_dir).exists()


@pytest.mark.parametrize("missing", ["csproj", "workflow", "activities", "program"])
def test_page2_build_leaves_missing_files_to_the_file_checks(tmp_path, fake_dotnet, missing):
    # A missing project or paste is reported by its own check, so the learner sees one hint.
    kwargs = {"csproj": False} if missing == "csproj" else {missing: None}
    ws = page2_workspace(tmp_path / "ws", **kwargs)
    rc, out = p2("build", ws, fake_dotnet, rc=1)
    assert rc == 0, out
    assert not fake_dotnet[1].exists(), "the build ran although a file check fails"


def test_page2_build_leaves_a_wrong_paste_to_the_file_checks(tmp_path, fake_dotnet):
    # The workflow pasted into Activities.cs too: check-activities reports it, not the build.
    ws = page2_workspace(tmp_path / "ws", activities=WORKFLOW_CS)
    assert p2("activities", ws)[0] != 0
    rc, out = p2("build", ws, fake_dotnet, rc=1)
    assert rc == 0, out
    assert not fake_dotnet[1].exists()


def test_page2_empty_workspace_fails_every_file_check(tmp_path):
    for name in ("workflow", "activities", "program"):
        assert p2(name, tmp_path)[0] != 0, name


def test_page2_workflow_fails_without_the_file(tmp_path):
    rc, out = p2("workflow", page2_workspace(tmp_path, workflow=None))
    assert rc != 0
    assert "DiagnosticsWorkflow.cs" in out


def test_page2_workflow_fails_on_a_wrong_paste(tmp_path):
    rc, out = p2("workflow", page2_workspace(tmp_path, workflow=ACTIVITIES_CS))
    assert rc != 0
    assert "class DiagnosticsWorkflow" in out


def test_page2_activities_fails_without_the_file(tmp_path):
    rc, out = p2("activities", page2_workspace(tmp_path, activities=None))
    assert rc != 0
    assert "Activities.cs" in out


def test_page2_activities_names_each_missing_class(tmp_path):
    # Half pasted: the last activity is cut off.
    half = ACTIVITIES_CS.split("public class NotifyBridgeActivity")[0]
    rc, out = p2("activities", page2_workspace(tmp_path, activities=half))
    assert rc != 0
    assert "NotifyBridgeActivity" in out
    assert "DiagnoseSubsystemActivity" not in out


def test_page2_program_fails_on_the_template(tmp_path):
    rc, out = p2("program", page2_workspace(tmp_path, program=TEMPLATE_PROGRAM_CS))
    assert rc != 0
    assert "AddDaprWorkflow" in out


def test_page2_program_fails_without_the_file(tmp_path):
    rc, out = p2("program", page2_workspace(tmp_path, program=None))
    assert rc != 0
    assert "Program.cs" in out


def test_page2_task_runs_every_check_with_its_own_message():
    conds = conditions("write_workflow")
    assert [c[0] for c in conds] == ["workflow", "activities", "program", "build"]
    assert [c[1] for c in conds] == [f"2-write-the-workflow/scripts/check-{n}.sh" for n in P2_CHECKS]
    for _, script, message in conds:
        assert (LAB / script).is_file(), script
        assert re.search(r"section [2-5]", message), message
    assert len({c[2] for c in conds}) == len(conds), "two conditions share a failure_message"
    block = task_block("write_workflow")
    assert "solve" not in block
    assert 'timeout           = "120s"' in block


def test_page2_lists_its_task():
    pages = (LAB / "pages.hcl").read_text()
    page = re.search(r'resource "page" "write_the_workflow" \{(.*?)\n\}', pages, re.S).group(1)
    assert "write_workflow = resource.task.write_workflow" in page
    md = (LAB / "2-write-the-workflow" / "assignment.md").read_text()
    tag = '<instruqt-task id="write_workflow"></instruqt-task>'
    assert md.count(tag) == 1
    assert md.index(tag) < md.rindex("\n---\n")
    assert "## " not in md[md.index(tag):md.rindex("\n---\n")]
