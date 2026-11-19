# Multi-example MSAL.NET Maintenance Pilot

This is a sandbox in `hossnrabbit/ms-identity-docs-code-dotnet`, not a rollout to
Azure-Samples. The catalog in `scripts/maintenance-samples.json` covers all 13
examples, but not all use MSAL.NET directly. Installing this harness changes no
sample source, dependencies, frameworks, credentials, or tenant settings.

## GitHub-Only Discovery Test

Current test branch: `test/msal-harness-e2e`. This is the MSAL.NET counterpart to
the separate IdWeb test in `hossnrabbit/active-directory-aspnetcore-webapp-openidconnect-v2`
on `test/idweb-harness-e2e`. Neither test changes a default branch.

After the branch is reviewed and published, dispatch `Release maintenance issue`
on this test branch with `detect_latest=true` and `dry_run=true`. Leave version,
release URL, and event key empty; package may retain `Microsoft.Identity.Client`.
This queries only NuGet's version index and compares exact references in the five
cataloged direct-MSAL samples. Numeric stable versions only; previews are ignored.
Feed failures fail the job rather than masquerading as no update. No restores,
SDK execution, source/package downloads, sign-in, or tenant credentials are needed.

Floating references such as `4.*` are reported as unresolved separately, never
treated as exact installed baselines. Discovery does not resolve them or claim
they are outdated. When an exact reference is older, repeating with `dry_run=false`
creates or reuses one bot-authored issue per package/version, including closed
issues. A current or newer exact reference alone does not trigger an issue.
If all references float, no issue is created; inspect the unresolved summary.
The official tag URL is a candidate, not verified source evidence.

There is no automatic Copilot assignment, PAT requirement, or ADO dependency in
this test workflow. Detection is not source-update approval. Future agent work
still requires approved no-PAT authentication, verified test-branch setup import,
matching original evidence, provenance checks, and independent planning/review.
Never downgrade or introduce MSAL into wrapper/browser/Easy Auth samples.

The weekday 07:37 UTC cron is intentionally inactive: GitHub schedules execute
only workflows on the default branch, and this job also requires the test ref.
Publishing or dispatching this branch does not activate periodic execution.
Default-branch activation and corresponding guard changes require separate
approval. No commit, push, live feed query, issue creation, or hosted result is
implied by local offline tests.

## Example Inventory

| Example | Existing authentication dependency | MSAL.NET release scope |
| --- | --- | --- |
| console-cli | Microsoft.Identity.Client 4.64.0 | Enabled; .NET 8 device code/silent |
| console-daemon | IdWeb.TokenCache 3.1.0; transitive MSAL use | Excluded; needs an IdWeb-aware adapter |
| desktop-winforms | Microsoft.Identity.Client 4.* | Enabled; .NET 8 Windows interactive/silent |
| desktop-winui | Microsoft.Identity.Client 4.* | Enabled; .NET 8 WinUI interactive/silent |
| desktop-wpf | Microsoft.Identity.Client 4.* | Enabled; .NET 8 Windows interactive/silent |
| spa-blazor-wasm | Microsoft.Authentication.WebAssembly.Msal 8.* | Excluded; browser MSAL, not MSAL.NET |
| web-api-azure-function | Functions SDK 4.4.0; Easy Auth | Excluded; no MSAL/IdWeb reference |
| web-api-obo-client | IdWeb/DownstreamApi 3.1.0 | Excluded; IdWeb-owned reference |
| web-api-obo-user | IdWeb/DownstreamApi 3.1.0 | Excluded; IdWeb-owned reference |
| web-api | IdWeb 3.7.1; .NET 9 bearer validation | Excluded; IdWeb-owned reference |
| web-app-aspnet | IdWeb/UI/DownstreamApi 3.8.0 | Excluded; IdWeb-owned reference |
| web-app-blazor-server | IdWeb/UI/DownstreamApi 3.1.0 | Excluded; IdWeb-owned reference |
| xplat-maui | Microsoft.Identity.Client 4.38.0 | Scoped; legacy .NET 6 Android/Windows, currently provenance-blocked |

The five direct-reference projects are routed independently. Never add MSAL.NET
references to excluded examples. Supporting their wrapper/browser releases
requires separate evidence and validation adapters, not a blanket MSAL bump.

## Historical Prototype Setup (Not For This Test Branch)

The following describes the earlier default-branch prototype, not current
activation instructions. Do not create a PAT, change secrets or policies, target
`main`, or enable assignment for this test. Use the discovery procedure above.

1. Review and publish these harness files to this fork's `main` branch. Nothing
   runs on push. Custom-agent and Copilot setup discovery must be verified after
   the files are on the default branch.
2. Enable Issues and Actions in the fork. Do not enable inherited deployment or
   publishing jobs. Keep Require approval for workflow runs enabled under
   Settings > Copilot > Cloud agent > Actions workflow approval. Automatic issue
   assignment does not require disabling this setting. An administrator can opt
   into automatic execution separately, but that allows unreviewed agent code to
   run with each workflow's permissions and secrets. It does not approve or merge
   a PR. Do not disable unrelated fork-contributor protections.
3. In Settings > Secrets and variables > Actions > Variables, set repository
   variable `MAINTENANCE_DISPATCH_ACTOR` to `hossnrabbit` for manual testing. If an
   approved ADO credential later belongs to another actor, update this value.
   The release job is skipped when the variable is missing or the actor differs.
4. Add `COPILOT_ASSIGNMENT_TOKEN` under Settings > Secrets and variables > Actions >
   Secrets. Use a user PAT scoped only to this sandbox repository, with metadata
   read and Actions, Contents, Issues, and Pull requests read/write permissions,
   as required by GitHub's Copilot assignment API. The user must have Copilot cloud
   agent access and the repository must allow it. A GitHub App user-to-server
   token is another supported credential; an installation token or the built-in
   `GITHUB_TOKEN` is not a substitute. Never commit or log tokens. Keep ADO's
   Actions-only dispatch credential separate and unchanged.
   An Issues-write-only PAT is being tested as a sandbox least-privilege
   experiment; it is not yet verified to start Copilot. Do not broaden token
   permissions automatically if assignment fails; inspect the actual error first.
5. Under Actions, manually run `Copilot setup steps`, then `Maintenance validation`
   on `main`. Inspect each sample's setup status and all platform jobs; a green
   static job does not prove every example built. These checks use no tenant credentials.
6. Manually run `Release maintenance issue`. Enter Microsoft.Identity.Client, an
   exact published target version, and its official MSAL.NET GitHub release URL.
   Leave `event_key` empty for a manual test; the workflow computes it. An ADO
   dispatch may supply the same key using the coordinator contract.
7. The workflow creates or reuses the issue with its built-in token, then uses the
   separate assignment secret to start `sample-implementer` in this fork on `main`.
   Missing credentials or a rejected assignment fail the run visibly. After fixing
   the prerequisite, rerun the same dispatch; an open, never-assigned issue can be
   reused for the handoff. Closed issues and issues currently or previously assigned
   to Copilot are skipped, including assignment events on later timeline pages.
   Replaying a release does not restart completed or manually stopped agent work.
   Copilot setup must prepare schema-2 `.maintenance-evidence/manifest.json` and
   the applicable baseline/target SDK trees before the session starts. The implementer reads that snapshot and
   supplies it to the planner. Release-note text alone is insufficient.
8. Inspect session logs for a real planner invocation, validation, and separate
   reviewer invocation. Missing delegation means BLOCKED, not a successful run.
   A separate eligible maintainer reviews the PR and a human decides whether to
   merge it, even if validation workflows run automatically.

The assignment API is in public preview. See GitHub's
[API documentation](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/use-cloud-agent-via-the-api)
and [workflow approval settings](https://docs.github.com/en/copilot/how-tos/use-copilot-agents/cloud-agent/configuring-agent-settings).
No tenant credential or ADO integration is needed for a manual workflow dispatch.
The assignment token is used only in the assignment step, not supplied to Copilot
setup or agent prompts. Manual Assign to agent remains a maintainer recovery option.

## Validation and Limits

Source acquisition runs inside `copilot-setup-steps.yml` BEFORE agent execution.
Setup resolves original references, downloads distinct applicable releases,
verifies NuGet/tag commits, and checks source/test
files and the manifest handoff in a separate Bash step. It writes the manifest to
`.maintenance-evidence/manifest.json` and exports `MSAL_SOURCE_MANIFEST` as a
convenience. The fixed repository-relative path does not depend on that environment
variable being available to the agent. Git ignores the entire evidence directory.

The pilot setup target defaults to 4.91.1. For a different release, a maintainer
must set the repository Actions variable `MSAL_SOURCE_TARGET_VERSION` BEFORE
starting a fresh session. The issue target must match the prepared manifest.
This is deliberately a single-target pilot, not concurrent multi-release routing.
The agent must not retry source acquisition or modify a prepared snapshot. Missing
or mismatched evidence is SETUP_BLOCKED and needs a setup repair/new session.

Use the hosted setup workflow, or the optional `source_target_version` input of
Maintenance validation, for source acquisition. Do not run local restores,
downloads, or builds where NuGet access is unavailable or forbidden.

The output directory must not already exist; the script refuses to overwrite a
snapshot. Use the printed manifest path. The script downloads official NuGet packages for
each applicable baseline and requested stable target, checks their repository commit
metadata against exact Git tags, and creates temporary source worktrees plus a
file-level comparison manifest. Its schema-2 `samples` array records id, project,
originalVersion, baselineVersion, targetVersion, and status. Its `comparisons`
array holds one entry per distinct applicable baseline, including changedFiles
and sourceDiffs. Each entry includes scenario-apis.diff and the broader
sdk-client.diff from those exact commits, with paths, path coverage, and
SHA256 hashes. Read patches in bounded ranges; the broader patch
can be large. These are source comparisons, not exhaustive public API inventories.
It never executes SDK code or builds the SDK.
Only exact three-part stable targets are supported. Original `4.*` references
are resolved once by trusted setup using official NuGet; this is a setup-time
snapshot, not proof of an earlier installed version. A newer resolved baseline
is marked newer and remains unchanged rather than being downgraded. Applicable
floating references are pinned to the exact verified target during maintenance.
If floating resolution fails, setup blocks rather than guessing an exact baseline.

A missing tag, commit metadata, provenance match, or network access for the target
blocks setup globally. A baseline-only failure marks its samples setup-blocked,
omits that comparison, and prohibits edits to those samples; other verified
samples may proceed with an explicit PARTIAL result. Do not invent evidence,
change baseline metadata, or weaken verification to clear a blocker.

Observed MAUI blocker: the 4.38.0 tag resolves to
`876737608b6cc6caaead87751ed7aa43f57738fb`, while its NuGet repository commit is
`7d8a50263eac6dd7e52365c278774c6be7f82a10`. This harness intentionally does not
authorize MAUI updates until a maintainer resolves that provenance discrepancy.
It also does not install or modernize the sample's legacy .NET 6 MAUI toolchain.
Downloads are anonymous; no GitHub API token/SAML grant is needed. Network access
must still be permitted by the hosted environment. Temporary artifacts are not
committed and must remain unchanged for planning, validation, and review.

Manually run Copilot setup steps after publishing the harness. Inspect the
Prepare verified SDK source and Verify source handoff steps before assigning a
new task. The earlier manual Maintenance validation source-fetch smoke check did
not prove that downloads could run inside the agent sandbox: issue #4 / PR #5
reported Resource temporarily unavailable there. Setup now removes that runtime
download requirement. Ordinary PR validation checks do not download SDK source.
Successful setup still does not prove the agent performed source analysis/review.

The implementer supplies the prepared diff paths up front and additional focused
comparisons on request. A planner NEEDS_EVIDENCE response is an intermediate
handoff: the implementer supplies the requested existing patch sections or runs
the focused read-only diff and reinvokes the planner. It must not stop merely
because the planner cannot execute commands. The read-only planner compares
each applicable sample's device-code, desktop-interactive, or mobile-interactive
and silent-token API contracts, implementation, and relevant
tests across BOTH release commits, not SDK main or only the final patch notes.
A newer verified release requires a package update, even if no code changes
are necessary. Do not mistake unchanged API usage for an already-current package.

## Scenario Improvement Discovery

The planner must assess ways to improve each applicable scenario, not merely preserve
compilable code. Discovery covers public parameters and optional/default values,
overloads, builders/options, deprecations, and behavioral changes across the
verified version range. Include relevant APIs NOT already called by the sample.
Review existing control flow, callback/cancellation, error handling, settings,
and result use critically against public contracts, implementations, and tests.
The package being current does not skip this assessment.

Return a scenario improvement matrix per sample with these fields for each candidate:

| Field | Required evidence |
| --- | --- |
| API and difference | Public symbol, baseline/target signature or behavior, parameter defaults |
| Provenance | Source/test paths at both commits, or proof the public API is newly added |
| Scenario benefit | Existing weakness or useful capability, applicability, defaults and tradeoffs |
| Decision | IMPLEMENT, DEFER, or NOT_APPLICABLE with a concrete rationale |
| Proposed change | Exact code/documentation edits, or approval needed for deferred scope |
| Validation | Meaningful checks, actual results in implementation, and remaining runtime checks |

Record inspected API families and diff/search coverage. NONE_FOUND requires an
evidence-backed negative assessment; UNKNOWN gaps cannot be presented as proof
that no useful additions exist. Missing required discovery blocks implementation.
The reviewer independently checks coverage and candidate decisions, including
whether useful optional parameters or other capabilities were overlooked.

Implement useful, source-supported improvements within the existing scenario and
that sample's bounded AGENTS.md file allowlist, even when compilation did not require the change.
Do not add explicit default arguments or use every new API just to create a diff.
A package-only update is still valid when the completed assessment justifies it.
New authentication scenarios, permissions, dependencies, tenant settings, or
files remain deferred for explicit maintainer approval.

Discovery and reviewer requirements are agent instructions, not an exhaustive
API-diff engine or a machine-enforced completeness check. CI checks the catalog,
harness guards, console build, and Windows desktop builds. Hosted logs and the PR matrix must show
actual discovery and independent review. No new unit-test suite or runtime
authentication automation is added by this harness change. For behavior that
cannot be exercised, report NOT RUN and specific manual/integration checks;
never describe compilation or inspecting SDK tests as runtime proof.

## Post-change Validation

Offline checks (no NuGet, SDK compilation, or sign-in):

```powershell
./scripts/Test-Maintenance.ps1
./scripts/Validate-Maintenance.ps1 -CheckOnly
```

After maintenance, check exact targets and immutable source evidence using the
ORIGINAL manifest, not a newly generated snapshot:

```powershell
./scripts/Validate-Maintenance.ps1 -ExpectedVersion 4.91.1 -EvidenceManifest ./.maintenance-evidence/manifest.json -CheckOnly
```

Use the actual target version after a maintenance edit. The script checks each
original framework expression and direct reference, plus original SDK/package
and diff hashes when supplied. A newer or setup-blocked sample retains its
original reference. Pass `-SampleId` to restrict a narrower issue or platform job.
Do not use one baseline version as the expected version for every unchanged sample.

On an approved hosted build runner only, the following require an actual build:

```powershell
# Linux or Windows console runner
./scripts/Validate-Maintenance.ps1 -SampleId console-cli -BuildPlatform any -RequireAllBuilds
# Windows runner; each desktop sample also has its own CI job
./scripts/Validate-Maintenance.ps1 -SampleId desktop-winforms,desktop-winui,desktop-wpf -BuildPlatform windows -RequireAllBuilds
```

For maintenance validation add the exact ExpectedVersion and original
EvidenceManifest arguments above. Default host builds omit MAUI, and Linux
omits Windows desktop. Missing builds print NOT RUN; `-RequireAllBuilds` fails if
any selected build is missing. `-CheckOnly` is never build evidence. MAUI requires
a separately approved compatible Windows/.NET 6 MAUI host and explicit
`-SampleId xplat-maui -BuildPlatform maui -RequireAllBuilds`; pass original
evidence for a maintenance task, which remains blocked on the discrepancy above.
There is no automated MAUI build or workload installation in this harness.
Report per-sample builds and PARTIAL outcomes honestly. These new hosted build
jobs have been prepared, not proven by local builds or a fresh hosted run.

There are no sample unit tests or automated authentication checks. The offline
harness regression suite is not application/authentication coverage.
Do not run `dotnet test` and describe a no-tests result as test coverage. Do not
run the app in CI: interactive authentication requires a human and an approved
test app/tenant. Build success is not proof of sign-in correctness.

All workflows are manual or PR-triggered; there are no public-issue/comment
triggers. The release workflow automatically assigns eligible release issues and only accepts
the configured actor, this fork, and the MSAL package, and deduplicates matching
repository/package/version issues, including closed issues. A URL is not proof
that a release exists: the source fetcher verifies NuGet/tag provenance before
the planner performs its source comparison. The first release-notes-only trial
in issue #2 / PR #3 was blocked on authenticated GitHub SAML access; use a NEW
issue for this source-aware harness. Leave the previous attempt untouched unless
a maintainer explicitly chooses to close it. Default Copilot tasks also load
.github/copilot-instructions.md, which routes maintenance through the role process.

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
files. The existing `validate-console-cli` check is retained. Review the new
`validate-harness`, `validate-desktop-winforms`, `validate-desktop-winui`, and
`validate-desktop-wpf` checks and appropriate branch
protection before treating this as production automation. Workflow execution on
PR code has risks with or without execution approval. The PR validation workflow
uses no tenant secrets and only reads repository contents; the release workflow
separately writes issues and uses a privileged user token for assignment. Audit
all PR-triggered workflows before enabling automatic execution.

First test an ordinary update, then a no-change case and an invalid/missing
release-evidence case. Record actual build outcomes and human corrections. Re-run
the same dispatch to verify no duplicate release issue is created. Only connect
ADO after the manual flow is proven. Do not enable release-wide fan-out yet.