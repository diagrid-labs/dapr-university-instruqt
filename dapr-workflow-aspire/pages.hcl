# Each page ends with a task (tasks.hcl) that checks what the page built, so the next page starts
# from a working solution. A page lists its task in `activities` together with the page's
# `<instruqt-task id="...">` tag (validate fails on an activity without its tag).
resource "page" "create_the_solution" {
  title = "Create the solution"
  file  = "1-create-the-solution/assignment.md"

  activities = {
    create_solution = resource.task.create_solution
  }
}

resource "page" "write_the_workflow" {
  title = "Write the workflow"
  file  = "2-write-the-workflow/assignment.md"

  activities = {
    write_workflow = resource.task.write_workflow
  }
}

resource "page" "orchestrate_with_aspire" {
  title = "Orchestrate with Aspire"
  file  = "3-orchestrate-with-aspire/assignment.md"

  activities = {
    orchestrate = resource.task.orchestrate
  }
}

resource "page" "run_and_inspect" {
  title = "Run and inspect"
  file  = "4-run-and-inspect/assignment.md"

  activities = {
    run_inspect = resource.task.run_inspect
  }
}
