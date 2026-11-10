# dapr-secrets

Dapr University lab: **Dapr Secrets - Read, Scope, and Swap Secret Stores**. Four challenges, about
30 minutes, in .NET, Python or Java. The learner reads a secret through the Secrets API, configures the
local file secret store, sees an app refused by secret scoping, then swaps the file store for HashiCorp
Vault without changing application code.

This is the first Instruqt 2.0 lab in the repo. The lab config lives in HCL (`main.hcl` holds the title,
description and time limits), not in this file. The demo apps are not here: they are cloned from
`diagrid-labs/ai-agent-tracks-instruqt` at the commit pinned in `versions.hcl`.

## File map

| Path | What it is |
| --- | --- |
| `main.hcl` | The `lab` resource: title, description, timeouts, chapter and page order |
| `versions.hcl` | Lab pins: `dapr_runtime_version`, `tracks_src_ref`, and the `diagrid/dapr-sandbox` module block (exact version) |
| `layouts.hcl`, `tabs.hcl`, `pages.hcl` | Layout, terminal/editor tabs, and the page for each challenge |
| `tasks.hcl` | The checks and solves behind each page's tasks |
| `scripts/lab-setup.sh` | Lab-specific VM setup (clone demo repo, `dapr init`, start Vault). Inlined into the VM startup by the module |
| `scripts/seed-vault.sh` | Sourceable library defining `seed_vault`, shared by `lab-setup.sh` and CI |
| `<n>-<slug>/assignment.md` | Learner instructions for each challenge |
| `<n>-<slug>/scripts/check-*.sh`, `solve.sh` | Per-task checks and the solve for the challenge |
| `<n>-<slug>/tests/challenge.robot` | Drift test for the challenge, run by CI |

Legacy 1.0 files (`_setup/`, `tabs.md`, per-challenge `README.md`, `setup.sh` and `check.sh`) are still
here and will be removed once the 2.0 lab is live.

## Checking your changes

```bash
# Validate the lab (the script swaps in a local copy of the shared module; plain
# `instruqt lab validate` cannot resolve the registry module)
tools/track-tester/ci/validate-lab.sh dapr-secrets modules/dapr-sandbox

# Drift tests (see tools/track-tester/README.md for setup)
(cd tools/track-tester && uv run robot --include python ../../dapr-secrets/*/tests/challenge.robot)
```

To preview a branch in Instruqt, see section 10 of the runbook.

## Deploying

The lab in Instruqt is connected to `main` with root directory `dapr-secrets`. Merging to `main`
deploys it. Pins and module versions are changed through a PR; see the maintenance procedures in the
[Instruqt 2.0 runbook](../docs/instruqt-2-runbook.md).
