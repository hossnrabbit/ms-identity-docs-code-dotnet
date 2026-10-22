# Console CLI Maintenance Pilot

This is a sandbox in `hossnrabbit/ms-identity-docs-code-dotnet`, not a rollout to
Azure-Samples. Only `console-cli` is in scope. Its baseline is .NET 8 with a direct
Microsoft.Identity.Client 4.64.0 dependency. Installing this harness does not
update that dependency or alter sample code.

## Enable the Prototype

1. Review and publish these harness files to this fork's `main` branch. Nothing
   runs on push. Custom-agent and Copilot setup discovery must be verified after
   the files are on the default branch.
2. Enable Issues and Actions in the fork. Do not enable inherited deployment or
   publishing jobs. Keep approval required for workflows on Copilot PRs.
3. In Settings > Secrets and variables > Actions > Variables, set repository
   variable `MAINTENANCE_DISPATCH_ACTOR` to `hossnrabbit` for manual testing. If an
   approved ADO credential later belongs to another actor, update this value.
   The release job is skipped when the variable is missing or the actor differs.
4. Under Actions, manually run `Copilot setup steps`, then `Maintenance validation`
   on `main`. Both must pass. These checks use no tenant credentials.
5. Manually run `Release maintenance issue`. Enter Microsoft.Identity.Client, an
   exact published target version, and its official MSAL.NET GitHub release URL.
   Leave `event_key` empty for a manual test; the workflow computes it. An ADO
   dispatch may supply the same key using the coordinator contract.
6. Inspect the issue, then use Assign to agent. Select Copilot and the
   `sample-implementer` custom agent, with this fork and `main` as the destination.
   Confirm the task has readable official release evidence; provide the relevant
   excerpt when the read-only planner cannot retrieve it.
7. Inspect session logs for a real planner invocation, validation, and separate
   reviewer invocation. Missing delegation means BLOCKED, not a successful run.
   Inspect changes before approving workflows. A separate eligible maintainer
   reviews the PR and a human decides whether to merge it.

No GitHub PAT, Copilot Requests token, tenant credential, or ADO integration is
needed for this manual path. The issue workflow uses its own GitHub Actions token
to create issues. Permission to assign Copilot comes from your GitHub access and
Copilot entitlement, not from that workflow token.

## Validation and Limits

```powershell
./scripts/Validate-Maintenance.ps1 -ExpectedVersion 4.64.0
```

Use the actual target version after a maintenance edit. The script checks the
direct package reference and net8.0 target, then restores and builds Release.
There are no automated unit tests or authentication checks in the initial pilot.
Do not run `dotnet test` and describe a no-tests result as test coverage. Do not
run the app in CI: device-code authentication requires a human and an approved
test app/tenant. Build success is not proof of sign-in correctness.

All workflows are manual or PR-triggered; there are no public-issue/comment
triggers and no automatic Copilot assignment. The release workflow only accepts
the configured actor, this fork, and the MSAL package, and deduplicates matching
repository/package/version issues, including closed issues. A URL is not proof
that a release exists: the planner must verify it before implementation.

Planner and reviewer profiles have read/search and read-only GitHub tools, not
edit or shell tools. Implementer has edit, shell, and delegation tools. Tool
restrictions apply when the runtime loads the named profile; prose scope limits
are guidance, not an OS security sandbox. GitHub.com ignores VS Code `handoffs`,
so the implementer explicitly invokes the roles instead. Confirm this works in
the hosted runtime rather than assuming the files prove orchestration.

No custom hooks or automatic review policy have been installed. The validation
workflow is the initial executable check. Future hooks should address observed
repeat mistakes and must be tested with the chosen hosted runtime. The reviewer
returns findings to the implementer; it does not post or approve GitHub reviews.
Built-in Copilot review settings are managed separately in repository settings.

Human merge requirements and required status checks are not configured by these
files. Configure the `validate-console-cli` check and appropriate branch
protection before treating this as production automation. Workflow execution on
PR code has risks even after approval; these workflows use no tenant secrets and
only read repository contents.

First test an ordinary update, then a no-change case and an invalid/missing
release-evidence case. Record actual build outcomes and human corrections. Re-run
the same dispatch to verify no duplicate release issue is created. Only connect
ADO after the manual flow is proven. Do not enable release-wide fan-out yet.