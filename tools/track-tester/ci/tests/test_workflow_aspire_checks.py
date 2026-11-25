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
PROGRAM_CS = "builder.Services.AddDaprWorkflow();\n"
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


# ---- Page 3: orchestrate with Aspire -----------------------------------------------------------
P3 = LAB / "3-orchestrate-with-aspire" / "scripts"
P3_CHECKS = ("apphost", "api", "dev-dashboard")

APPHOST_CS = """#:package Aspire.Hosting.AppHost@17.0.0
#:package Aspire.Hosting.Dotnet@17.0.0
#:package CommunityToolkit.Aspire.Hosting.Dapr@13.0.0

using CommunityToolkit.Aspire.Hosting.Dapr;

var builder = DistributedApplication.CreateBuilder(args);

var stateStore = builder.AddDaprComponent("statestore", "state.redis")
    .WithMetadata("redisHost", "localhost:6379")
    .WithMetadata("actorStateStore", "true");

builder.AddDotnetProject("engineering", "./Engineering/Engineering.csproj")
    .WithHttpEndpoint(port: 5411, name: "api")
    .WithDaprSidecar(sidecar => sidecar.WithReference(stateStore));

builder.AddExecutable("dev-dashboard", "diagrid-dev-dashboard", ".",
        "--port", "9090", "--bind", "0.0.0.0", "--no-open", "--mode", "aspire")
    .WithHttpEndpoint(port: 9090, isProxied: false);

builder.Build().Run();
"""
# The AppHost as `aspire new aspire-empty` creates it (page 1).
TEMPLATE_APPHOST_CS = """#:package Aspire.Hosting.AppHost@17.0.0
#:package Aspire.Hosting.Dotnet@17.0.0

var builder = DistributedApplication.CreateBuilder(args);

builder.Build().Run();
"""


def page3_workspace(root, apphost=APPHOST_CS):
    sol = root / "MeridianDiagnostics"
    sol.mkdir(parents=True)
    if apphost is not None:
        (sol / "apphost.cs").write_text(apphost)
    return root


class _Server:
    """A local HTTP server that answers every GET with `code` and records the Host header and path."""

    def __init__(self, code):
        import http.server
        import threading

        self.code, self.requests = code, []
        server = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def do_GET(self):  # noqa: N802
                server.requests.append((self.path, self.headers.get("Host")))
                self.send_response(server.code)
                self.end_headers()
                self.wfile.write(b"{}")

            def log_message(self, *args):
                pass

        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.httpd.shutdown()
        self.httpd.server_close()


@pytest.fixture
def http_server():
    servers = []

    def make(code=200):
        s = _Server(code)
        servers.append(s)
        return s

    yield make
    for s in servers:
        s.close()


def _closed_port_url():
    import socket
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        port = s.getsockname()[1]
    return f"http://127.0.0.1:{port}"


def p3(name, workspace, **env):
    r = subprocess.run(["bash", str(P3 / f"check-{name}.sh")],
                       env={**os.environ, "WORKSPACE": str(workspace), **env},
                       capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout + r.stderr


def test_page3_all_checks_pass(tmp_path, http_server):
    ws = page3_workspace(tmp_path / "ws")
    api, dd = http_server(404), http_server(200)
    before = snapshot(ws)
    env = {"ENGINEERING_URL": api.url, "DEV_DASHBOARD_URL": dd.url}
    for name in P3_CHECKS:
        rc, out = p3(name, ws, **env)
        assert rc == 0, f"{name}: {out}"
    assert snapshot(ws) == before, "a page 3 check changed the workspace"


def test_page3_checks_default_to_the_lab_ports():
    for name, url in (("api", "http://localhost:5411"), ("dev-dashboard", "http://localhost:9090")):
        text = (P3 / f"check-{name}.sh").read_text()
        assert url in text, name
        assert "/root/university-labs/workflow-aspire" in (P3 / "check-apphost.sh").read_text()


def test_page3_apphost_fails_without_the_file(tmp_path):
    rc, out = p3("apphost", page3_workspace(tmp_path, apphost=None))
    assert rc != 0
    assert "apphost.cs" in out


def test_page3_apphost_fails_on_the_template(tmp_path):
    rc, out = p3("apphost", page3_workspace(tmp_path, apphost=TEMPLATE_APPHOST_CS))
    assert rc != 0
    for part in ("CommunityToolkit.Aspire.Hosting.Dapr", "statestore", "engineering", "dev-dashboard"):
        assert part in out, part


@pytest.mark.parametrize("drop, named", [
    ("#:package CommunityToolkit.Aspire.Hosting.Dapr@13.0.0\n", "CommunityToolkit.Aspire.Hosting.Dapr"),
    ('builder.AddDaprComponent("statestore", "state.redis")', "statestore"),
    ('builder.AddDotnetProject("engineering", "./Engineering/Engineering.csproj")', "engineering"),
    (".WithDaprSidecar(sidecar => sidecar.WithReference(stateStore))", "WithDaprSidecar"),
    ('builder.AddExecutable("dev-dashboard", "diagrid-dev-dashboard", ".",', "dev-dashboard"),
])
def test_page3_apphost_names_each_missing_part(tmp_path, drop, named):
    assert drop in APPHOST_CS
    rc, out = p3("apphost", page3_workspace(tmp_path, apphost=APPHOST_CS.replace(drop, "")))
    assert rc != 0
    assert named in out


def test_page3_empty_workspace_fails_the_apphost_check(tmp_path):
    assert p3("apphost", tmp_path)[0] != 0


def test_page3_api_fails_when_nothing_answers(tmp_path):
    rc, out = p3("api", tmp_path, ENGINEERING_URL=_closed_port_url())
    assert rc != 0
    assert "does not answer" in out


@pytest.mark.parametrize("code", [200, 404])
def test_page3_api_passes_when_the_status_endpoint_answers(tmp_path, http_server, code):
    api = http_server(code)
    rc, out = p3("api", tmp_path, ENGINEERING_URL=api.url)
    assert rc == 0, out
    assert api.requests and api.requests[0][0].startswith("/status/")


def test_page3_api_fails_on_a_server_error(tmp_path, http_server):
    # The app runs but its status endpoint fails, for example when the sidecar is not there.
    rc, out = p3("api", tmp_path, ENGINEERING_URL=http_server(500).url)
    assert rc != 0
    assert "500" in out


def test_page3_dev_dashboard_sends_a_loopback_host(tmp_path, http_server):
    # The Dev Dashboard rejects a non-loopback Host header when it binds 0.0.0.0.
    dd = http_server(200)
    rc, out = p3("dev-dashboard", tmp_path, DEV_DASHBOARD_URL=dd.url)
    assert rc == 0, out
    assert dd.requests and all(host == "localhost:9090" for _, host in dd.requests)


def test_page3_dev_dashboard_fails_when_nothing_answers(tmp_path):
    rc, out = p3("dev-dashboard", tmp_path, DEV_DASHBOARD_URL=_closed_port_url())
    assert rc != 0
    assert "does not answer" in out


def test_page3_dev_dashboard_fails_on_a_rejected_host(tmp_path, http_server):
    rc, out = p3("dev-dashboard", tmp_path, DEV_DASHBOARD_URL=http_server(403).url)
    assert rc != 0
    assert "403" in out


def test_page3_task_runs_every_check_with_its_own_message():
    conds = conditions("orchestrate")
    assert [c[0] for c in conds] == ["apphost", "api", "dev_dashboard"]
    assert [c[1] for c in conds] == [f"3-orchestrate-with-aspire/scripts/check-{n}.sh" for n in P3_CHECKS]
    for _, script, message in conds:
        assert (LAB / script).is_file(), script
        assert re.search(r"section [1-4]", message), message
    assert len({c[2] for c in conds}) == len(conds), "two conditions share a failure_message"
    # The API check tells the learner where to start the app.
    api_message = conds[1][2]
    assert "aspire run" in api_message and "Aspire CLI" in api_message
    block = task_block("orchestrate")
    assert "solve" not in block
    assert 'timeout           = "30s"' in block


def test_page3_lists_its_task():
    pages = (LAB / "pages.hcl").read_text()
    page = re.search(r'resource "page" "orchestrate_with_aspire" \{(.*?)\n\}', pages, re.S).group(1)
    assert "orchestrate = resource.task.orchestrate" in page
    md = (LAB / "3-orchestrate-with-aspire" / "assignment.md").read_text()
    tag = '<instruqt-task id="orchestrate"></instruqt-task>'
    assert md.count(tag) == 1
    assert md.index(tag) < md.rindex("\n---\n")
    assert "## " not in md[md.index(tag):md.rindex("\n---\n")]


def test_page3_apphost_fixture_is_the_page_apphost():
    # The fixture above is the AppHost the page writes, so the pass test covers the real file.
    md = (LAB / "3-orchestrate-with-aspire" / "assignment.md").read_text()
    assert "cat > MeridianDiagnostics/apphost.cs <<'EOF'\n" + APPHOST_CS.replace(
        "\nvar stateStore", "\n// The workflow state store: the Redis container that `dapr init` started.\nvar stateStore"
    ) + "EOF\n" in md


# ---- Page 4: run and inspect -------------------------------------------------------------------
P4 = LAB / "4-run-and-inspect" / "scripts"
P4_PAGE = LAB / "4-run-and-inspect" / "assignment.md"
RUN_IDS = ("jump-001", "jump-002")
COMPLETED = ('{"status":"Completed","output":{"starDate":"47634.4","priority":"Urgent",'
             '"summary":"WarpCore=Nominal, LifeSupport=Degraded, Shields=Critical","bridgeNotified":true}}')


def status_body(status):
    return COMPLETED if status == "Completed" else '{"status":"%s","output":null}' % status


class _StatusServer:
    """A stand-in for the engineering API: GET /status/<id> answers from `runs` (id -> status, or an
    int HTTP code), 404 for an unknown id. Records every request's method and path."""

    def __init__(self, runs):
        import http.server
        import threading

        self.runs, self.requests = runs, []
        server = self

        class Handler(http.server.BaseHTTPRequestHandler):
            def _answer(self):
                server.requests.append((self.command, self.path))
                run = server.runs.get(self.path.rsplit("/", 1)[-1]) if self.path.startswith("/status/") else None
                if run is None:
                    code, body = 404, ""
                elif isinstance(run, int):
                    code, body = run, "System.Text.Json.JsonException: ..."
                else:
                    code, body = 200, status_body(run)
                self.send_response(code)
                self.end_headers()
                self.wfile.write(body.encode())

            do_GET = do_POST = do_PUT = do_DELETE = _answer  # noqa: N815

            def log_message(self, *args):
                pass

        self.httpd = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.httpd.server_address[1]}"
        self.thread = threading.Thread(target=self.httpd.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.httpd.shutdown()
        self.httpd.server_close()


@pytest.fixture
def engineering():
    servers = []

    def make(**runs):
        s = _StatusServer({k.replace("_", "-"): v for k, v in runs.items()})
        servers.append(s)
        return s

    yield make
    for s in servers:
        s.close()


def p4(url):
    r = subprocess.run(["bash", str(P4 / "check-completed.sh")],
                       env={**os.environ, "ENGINEERING_URL": url}, capture_output=True, text=True, timeout=60)
    return r.returncode, r.stdout + r.stderr


@pytest.mark.parametrize("runs", [
    {"jump_001": "Completed"},
    {"jump_002": "Completed"},
    {"jump_001": "Completed", "jump_002": "Running"},
    {"jump_001": 500, "jump_002": "Completed"},
])
def test_page4_completed_passes_when_a_run_completed(engineering, runs):
    api = engineering(**runs)
    rc, out = p4(api.url)
    assert rc == 0, out
    assert "Completed" in out or "completed" in out
    # Read-only: it only asks for the status of the page's two runs.
    assert {m for m, _ in api.requests} == {"GET"}
    assert {p for _, p in api.requests} <= {f"/status/{i}" for i in RUN_IDS}


@pytest.mark.parametrize("status", ["Running", "Pending"])
def test_page4_completed_asks_to_wait_while_a_run_is_still_going(engineering, status):
    # Review Focus 4: the learner selects Check during the 15 second timer.
    rc, out = p4(engineering(jump_001=status).url)
    assert rc != 0
    assert "jump-001" in out and status in out
    assert "wait until it completes" in out and "check again" in out


def test_page4_completed_fails_when_no_run_was_started(engineering):
    rc, out = p4(engineering().url)
    assert rc != 0
    assert "jump-001" in out and "section 1" in out


@pytest.mark.parametrize("status", ["Failed", "Terminated"])
def test_page4_completed_names_a_run_that_did_not_complete(engineering, status):
    rc, out = p4(engineering(jump_001=status).url)
    assert rc != 0
    assert f"jump-001 is {status}" in out


def test_page4_completed_reports_a_status_it_cannot_read(engineering):
    rc, out = p4(engineering(jump_001=500).url)
    assert rc != 0
    assert "jump-001" in out and "HTTP 500" in out


def test_page4_completed_leaves_a_stopped_app_to_the_api_check():
    # Review Focus 5: engineering is stopped. The api condition names the fix; this one stays quiet,
    # so the learner gets one hint.
    rc, out = p4(_closed_port_url())
    assert rc == 0, out
    assert "does not answer" in out


def test_page4_completed_defaults_to_the_lab_port_and_the_page_ids():
    text = (P4 / "check-completed.sh").read_text()
    assert "http://localhost:5411" in text
    for run_id in RUN_IDS:
        assert run_id in text


def test_page4_task_checks_the_app_and_a_completed_run():
    conds = conditions("run_inspect")
    assert [c[0] for c in conds] == ["api", "completed"]
    # The api condition reuses page 3's read-only probe of the status endpoint.
    assert [c[1] for c in conds] == ["3-orchestrate-with-aspire/scripts/check-api.sh",
                                     "4-run-and-inspect/scripts/check-completed.sh"]
    for _, script, message in conds:
        assert (LAB / script).is_file(), script
        assert re.search(r"section [1-6]", message), message
    api_message, completed_message = conds[0][2], conds[1][2]
    # Review Focus 5: how to start engineering again, in the dashboard and with the CLI.
    for text in ("Aspire tab", "Start", "aspire resource engineering start --apphost MeridianDiagnostics/apphost.cs",
                 "curl window", "aspire run", "Aspire CLI"):
        assert text in api_message, text
    # Review Focus 4: a run that has not finished yet.
    assert "wait until it completes" in completed_message and "check again" in completed_message
    block = task_block("run_inspect")
    assert "solve" not in block
    assert 'timeout           = "30s"' in block


def test_page4_lists_its_task():
    pages = (LAB / "pages.hcl").read_text()
    page = re.search(r'resource "page" "run_and_inspect" \{(.*?)\n\}', pages, re.S).group(1)
    assert "run_inspect = resource.task.run_inspect" in page
    md = P4_PAGE.read_text()
    tag = '<instruqt-task id="run_inspect"></instruqt-task>'
    assert md.count(tag) == 1
    close = md.index("\n---\n")
    assert md.index(tag) < close
    assert "## " not in md[md.index(tag):close]


def test_page4_stop_and_start_commands_match_the_task_message():
    # The CLI fallback on the page is the command the api failure_message names.
    md = P4_PAGE.read_text()
    for verb in ("stop", "start"):
        assert f"aspire resource engineering {verb} --apphost MeridianDiagnostics/apphost.cs" in md, verb


BADGE_COLLECT = "https://holopin.io/collect/TODO-workflow-aspire"
BADGE_IMAGE = ("https://github.com/diagrid-labs/dapr-university-instruqt/blob/main/dapr-workflow-aspire/"
               "4-run-and-inspect/images/Diagrid-Dapr-Uni-badge-wf-aspire_x300.png?raw=true")


def test_page4_closes_the_track_with_the_badge():
    md = P4_PAGE.read_text()
    intro = md.split("\n## ", 1)[0]
    assert "Holopin badge" in intro
    close = md[md.index("\n---\n"):]
    assert "## Collect your badge & provide feedback" in close
    # The image at 384 x 384, linked to the collect URL (a placeholder until the badge is live).
    assert f'<a href="{BADGE_COLLECT}"><img src="{BADGE_IMAGE}"' in close
    assert 'width="384" height="384"' in close
    assert f"]({BADGE_COLLECT})" in close
    # The recap has one line per page, named by the page titles.
    for title in ("Create the solution", "Write the workflow", "Orchestrate with Aspire", "Run and inspect"):
        assert f"**{title}:**" in close, title
    # Further learning.
    for url in ("https://www.diagrid.io/university/dapr-workflow)", "https://www.diagrid.io/university/ai-agents-maf)"):
        assert url in close, url
    assert close.rstrip().endswith('<instruqt-completion text="You\'ve completed Dapr Workflow with .NET Aspire!"></instruqt-completion>')


def test_page4_stops_aspire_at_the_end():
    md = P4_PAGE.read_text()
    close = md[md.index("\n---\n"):]
    assert "Ctrl+C" in close and "Aspire CLI" in close
