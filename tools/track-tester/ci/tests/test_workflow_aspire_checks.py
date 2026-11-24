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
