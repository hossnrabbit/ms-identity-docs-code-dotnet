# Shared Identity Sample Maintenance

This is a sandbox in `hossnrabbit/ms-identity-docs-code-dotnet`, not a rollout to
Azure-Samples. The catalog in `scripts/maintenance-samples.json` covers all 13
examples, but not all use MSAL.NET directly. Installing this harness changes no
sample source, dependencies, frameworks, credentials, or tenant settings.

## GitHub-Only Discovery Test

There is ONE harness on `test/msal-harness-e2e` for releases from either
`AzureAD/microsoft-authentication-library-for-dotnet` or
`AzureAD/microsoft-identity-web`. The branch name is retained for compatibility,
not SDK-specific routing. The earlier IdWeb-specific test entry point is retired.
One catalog, detector, evidence schema, validator, and implementer/planner/reviewer
process select the relevant upstream from the requested package. The approved
fork-default bootstrap now imports this shared setup and the three tested agent
profiles. Supporting another package does not require another harness.

On the published test branch, dispatch `Release maintenance issue`
on this test branch with `detect_latest=true` and `dry_run=true`. Leave version,
release URL, event key, and package empty to check both upstreams, or specify an
existing package to filter the scan. This queries only NuGet's version indexes
and compares the cataloged direct references. Numeric stable versions only; previews are ignored.
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
still requires matching non-secret Agents configuration, verified test-branch setup import,
matching original evidence, provenance checks, and independent planning/review.
Never downgrade or introduce MSAL into wrapper/browser/Easy Auth samples.

The weekday 07:37 UTC cron is intentionally inactive: GitHub schedules execute
only workflows on the default branch, and this job also requires the test ref.
Publishing or dispatching this branch does not activate periodic execution.
Periodic default-branch activation and corresponding guard changes require separate
approval. No commit, push, live feed query, issue creation, or hosted result is
implied by local offline tests.

## NuGet-Commit Provenance Policy

Source identity is the full commit recorded in each official NuGet package, not
the release tag. Trusted setup checks the exact package identity/version and
expected official repository, fetches that commit anonymously from that repository,
and materializes it without substitution. The schema-2 manifest requires
`sourceProvenance: nuget-repository-commit`. Validation re-reads the original
package metadata and checks its commit against the clean source HEAD, preserving
package and prepared-diff SHA256 checks. Older tag-only manifests must be prepared
again; they are not silently accepted under this policy.

`tagObservation` records matches, differs, or unavailable and the observed tag
commit/diagnostics. Tags supplement release notes; missing or differing tags are
warnings, not source blockers. Missing/invalid metadata, the wrong official
repository, unavailable declared commits, and altered evidence remain blockers.
The historical runs below retain their original strict-tag outcomes.

Manual shared setup can accept `smoke_sample` for one existing cross-platform
sample. It temporarily pins only that direct package reference, runs strict
evidence-aware validation and a required hosted build, restores the exact original
project bytes, and verifies the checkout is pristine. This exercises the
source-to-update/build path; it is not an agent discovery assessment or reviewed PR.
Trusted setup uses `-SetupCheck -CheckOnly` to validate original references;
normal update validation remains strict and must not use SetupCheck.

## Latest Reviewed-Agent Trials

The user approved changing this fork's default bootstrap. Commit
`6abdf957d401bb7ac46091066c1b4f0c1557d784` copied exactly the shared setup workflow
and three tested agent profiles. A workflow-only follow-up at
`ebe0ee18a1b1041f27f6b8f00969b273556ba5df` reads imported Agents environment
variables when explicit workflow inputs are absent. Both updates were non-forced
and verified against the exact tested blobs. No sample, discovery schedule,
secret, permission policy, upstream repository, or retired fork was changed.

GitHub does not pass repository Actions variables to Copilot sessions. The first
Client task consequently stopped SETUP_BLOCKED with no sample changes:
[run 45284153738](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45284153738).
Its empty [PR 24](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/pull/24)
was verified and closed. Separate repository Agents variables supplied matching
package/target values for the repaired Client trial and then the IdWeb trial.
After both sessions completed, those two temporary variables were deleted;
Agents variables are again empty and the original Actions dispatcher variable
remains unchanged. New sessions must configure their matching target explicitly.

| Trial | Actual result | Evidence |
| --- | --- | --- |
| Client 4.64.0 to 4.92.0, console-cli | Matching NuGet-backed setup; real planner READY before edits; first reviewer CHANGES_REQUIRED, one evidence/handoff repair, second reviewer PASS on `2f9b7cff0260013466ad982767cf78155f9d7ae5`; original-manifest validation and required console build passed | [Task](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/tasks/760feb95-a2a2-4174-96bb-2edf2a522571), [agent run 45284770473](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45284770473), [draft PR 25](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/pull/25) |
| Client final hosted matrix | All 11 jobs PASS on composite `539020600aa1d8febf757eee06d795fbcfea52db`; three reviewed sample blobs unchanged; separate maintainer fixture-only follow-up | [Run 45444954329](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45444954329) |
| Web 3.1.0 to 4.18.0, web-api-obo-client | Matching NuGet-backed setup; planner NEEDS_EVIDENCE then BLOCKED on missing Abstractions public contracts and resolved mixed-version graph; zero files changed, no reviewer or updated-sample validation | [Task](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/tasks/2f952e40-0b12-476f-9177-788d49fabd09), [agent run 45287606724](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45287606724), [blocked draft PR 26](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/pull/26) |
| Approved supplemental Web source/dependency smoke | PASS; original references preserved except disposable Web target; Abstractions source and both graphs verified; required disposable build passed and original project restored | [Run 45447581069](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45447581069) |
| Same Web trial after supplemental import | Actual imported supplement verified; real planner NEEDS_EVIDENCE then BLOCKED on the expanded interface/mixed-graph compatibility boundary; no application edits, reviews, repairs or candidate build | [Task](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/tasks/c3824699-30c2-40c5-b354-c5d12399a246), [agent run 45449009768](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45449009768), [source-backed blocker matrix](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/pull/26#issuecomment-7139432962) |
| Supplemental bootstrap hosted matrix | All 11 jobs PASS on unchanged application head `8d49822e5eed1721ba9f733082216e2e2e915515`; harness-only bootstrap, not a reviewed Web update | [Run 45449009417](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45449009417) |

The Client sample pins 4.92.0, forwards silent-acquisition exception claims to
the existing device-code fallback, and propagates best-effort Ctrl+C cancellation
through token acquisition and Graph requests with handler cleanup. Graph-issued
claims-challenge discovery/retry and persistent cache snapshots were deferred;
other discovered candidates were explicitly classified, not silently adopted.
The actual SDK source/test inspection and role handoffs are in session
`c07995ba-0a77-4dcd-a0ad-ca0137f53a03`, available with `gh agent-task view --log`.

The first final Client matrix
[45287580215](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45287580215)
passed all ten sample builds but failed the synthetic setup fixture: its
hard-coded 4.91.1 target was older than the newly updated console reference.
The fixture-only repair at `0d7e1510a60bb7f917cbe705d9c0ca2da22bf9ac` derives a
strictly newer synthetic target; offline checks passed against both 4.64.0 and
an isolated 4.92.0 project. Production disposition checks were not weakened.
The same fixture blob was applied to PR 25 without changing any reviewed sample
blob. Its three-way PR diff therefore contains the three sample files plus that
one test script. The independent verdict is bound to the original sample
revision, not claimed as a new review of the composite commit. No additional
review, merge, approval-policy change, or review-budget reset was performed.

IdWeb source verification succeeded at baseline
`63bc10edb7052622c6d4aee0e32e68000dee94ae` and target
`df82ea2c21e2fde81c3deb56578654b05fd59676`; the target's unavailable tag remained
advisory. The missing evidence concerns Microsoft.Identity.Abstractions contracts
and the graph combining Web 4.18.0 with the preserved DownstreamApi 3.1.0 reference.
This is not a provenance failure. The approved extension now supplies both
original restore graphs and NuGet-pinned Abstractions source. Its first imported
attempt stopped before planning because the optional selector was missing at
setup time; the workflow-only expression repair made the subsequent import pass.
Both continuations reused PR 26 and its original review budget, not a new issue.
A green agent job alone is not an implemented or reviewed IdWeb update.

The supplemented baseline resolves Abstractions 6.0.0 at
`0e09887e30dfbe3dd28230e3f3028e0b3ee1e312`; the target resolves 12.7.0 at
`76944ea3aa506494c16f7b1a67ec83538f631ba6`, from the official
`AzureAD/microsoft-identity-abstractions-for-dotnet` package repositories. The
target graph preserves DownstreamApi 3.1.0 but uses Web/TokenAcquisition 4.18.0
and Abstractions 12.7.0/net8. That interface adds abstract `JsonTypeInfo` overloads
not found in the old downstream implementation. The planner could not establish
safe type loading/DI for this exact mixed graph; restore or compilation does not
settle it. No runtime failure is claimed. The durable matrix is explicitly
provisional, with unresolved coverage, not a discovery PASS.

Session `74f13c7a-cd93-40c4-8737-9a8a327b5a63` supplied both manifests to the
real planner, then additional bounded source evidence after NEEDS_EVIDENCE; its
final verdict remained BLOCKED. No application candidate, reviewer or required
candidate build exists. The one-repair/two-review budget remains unused. Current
PR 26 head `8d49822e5eed1721ba9f733082216e2e2e915515`, tree
`0ff93a20d59e6e1e769d52ce3c16644c9b83f4a5`, contains only maintainer harness
bootstrap changes relative to the original blocked head. Resolving this boundary
requires authoritative compatibility evidence or explicit approval for a
coordinated dependency change; DownstreamApi was not silently upgraded.

After both sessions completed, all three temporary Agents variables were removed
and the original empty Agents state was verified. The Actions dispatcher variable,
Client PR 25, issue states and retired fork remained untouched. The approved fork
default now contains the tested workflow-only repair at
`8389721b30b1430fba6184bc062944b2fe4fc0df`. No permission/policy or schedule change,
merge, review-budget reset, local SDK operation or live authentication was made.

Both PRs remain draft and unmerged. SDK unit tests, live sign-in, claims and
cancellation integration tests, and MAUI builds were NOT RUN. Client dependency
vulnerability analysis was NOT RUN after its tool could not authenticate.

## Live NuGet-Commit Test: 2026-11-23

Published runtime `4de4bbb83106b29ddb2ab2d0fc99943105b15d13` passes both
package-selected source-to-update/build smokes and all eleven baseline validation
jobs. This supersedes the historical tag-only source blockers, not the remaining
real-agent setup prerequisite at that point. No sample changes were retained
from these historical smokes; the latest actual trials above supersede their
default-bootstrap and implementation status.

| Check | Verified result | Evidence |
| --- | --- | --- |
| Client 4.92.0 source-to-build | PASS; five selected clients, three exact source releases, disposable console-cli update to 4.92.0 and required build, original project restored | [Run 45282230920](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45282230920) |
| Web 4.18.0 source-to-build | PASS; five existing direct Web references, four exact source releases, disposable web-api-obo-client update to 4.18.0 and required build, original project restored | [Run 45282234302](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45282234302) |
| Final baseline validation | PASS; eleven jobs including all three Windows desktops and six server samples | [Run 45282238135](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45282238135) |
| Actual account-based setup guard | SETUP_BLOCKED correctly; requested Client 4.92.0, imported original Client 4.91.1 evidence; zero changed files | [Task](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/tasks/b3ba535c-5bb3-441c-80e3-0f5ae0459099), [run 45282065299](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45282065299) |

Client 4.92.0 uses NuGet commit `2465fc31fa2b481b68660670e2becfd3fba7c631`;
the different tag is advisory. Web 4.18.0 uses
`df82ea2c21e2fde81c3deb56578654b05fd59676`; the unavailable tag is advisory.
Client 4.38.0 source now verifies at
`7d8a50263eac6dd7e52365c278774c6be7f82a10`, despite its different tag.
No declared commit was replaced with a tag or moving branch.

The first hosted Client run [45281472161](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45281472161)
exposed a Linux fixture returning both `/usr/bin/git` and `/bin/git`; the fixture
now selects one executable. The next run [45281944305](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45281944305)
passed assertions but leaked an intentionally failed Git fetch's exit code into
Actions; successful tests now explicitly return zero. Setup-only validation also
uses the separately tested `-SetupCheck -CheckOnly` gate for pristine references;
normal target/update validation remains strict. Final runs above include these fixes.

At the time of this guard probe, GitHub's registered default-branch setup still
invoked the forwarding shim with `MSAL_SOURCE_TARGET_VERSION=4.91.1`. No default branch, setup variables,
secrets, permission policies, schedules, or issue assignment state was changed.
The read-only task stopped on that mismatch without an implementation or review.
The service created an empty draft despite `create_pull_request=false`; its
[PR 23](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/pull/23) was verified
to contain zero changed files and closed. Its service-created initial-plan commit
is not a maintenance implementation. Historical issue 18/PR 19 remain untouched;
issue 21 remains open/unassigned and issue 22 remains closed/unassigned.

At that point, a real reviewed latest-target agent update was BLOCKED pending explicit
approval to activate matching shared setup on the default branch and configure
the non-secret package/target variables. Standalone smoke success cannot supply
evidence to another agent session. No independent planner/reviewer or final
maintenance-PR build is claimed. MAUI builds, SDK unit tests, and sign-in remain
NOT RUN. The passing smokes exercise package updates/builds, not source-supported
scenario improvement discovery or authentication behavior.

## Historical Live Fork Test: 2026-11-23

The unified harness and retired duplicate entry point are published on their
existing test branches. All 11 hosted validation jobs passed at runtime commit
`4e6d73039defee0e6d620addae97462970331e8d`: offline harness, console, six IdWeb
server samples, and three Windows desktop samples. These are baseline sample
builds, not builds of a new maintenance PR. The latest-release update E2E is
BLOCKED, not successful.

| Check | Verified result | Evidence |
| --- | --- | --- |
| Both-upstream discovery dry run | PASS; Client 4.92.0 and existing Web-family packages 4.18.0; no assignment | [Run 45267120602](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45267120602) |
| Client release issue | PASS; created issue 21 | [Run 45267543950](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45267543950), [issue 21](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/issues/21) |
| Web release issue | PASS; created issue 22 | [Run 45267551061](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45267551061), [issue 22](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/issues/22) |
| Open Client issue replay | PASS; reused issue 21, remained open/unassigned, no duplicate | [Run 45268022193](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45268022193) |
| Closed Web issue replay | PASS; reused issue 22, remained closed/unassigned, no duplicate | [Run 45268028143](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45268028143) |
| Client 4.92.0 source setup | BLOCKED; tag/NuGet commit mismatch | [Run 45267555610](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45267555610) |
| Web 4.18.0 source setup | BLOCKED; exact official tag absent | [Run 45267559356](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45267559356) |
| Known Client 4.91.1 source smoke | PASS for target and console baseline; MAUI baseline blocked | [Run 45268033883](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45268033883) |
| Account-based read-only agent probe | PASS for task start, test checkout, setup import and original-manifest read; zero changed files, no PR | [Task](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/tasks/8217e31f-ba45-4389-82a8-68e3a975245d), [run 45269020326](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45269020326) |
| Final runtime validation | PASS; all 11 jobs | [Run 45269748141](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45269748141) |
| Retired IdWeb entry point | PASS; redirect ran, issue job skipped | [Run 45267050106](https://github.com/hossnrabbit/active-directory-aspnetcore-webapp-openidconnect-v2/actions/runs/45267050106) |

Client 4.92.0 tag commit `4392f63e5ad7232ee338ff9cd4a9c7463ae1c6ff` differs
from NuGet commit `2465fc31fa2b481b68660670e2becfd3fba7c631`. IdWeb setup
could not fetch `refs/tags/4.18.0`. Neither failure was bypassed or replaced
with alternative source. The known-release smoke test is not a substitute for
latest-release evidence. Replaying 4.91.1 also correctly reused historical
issue 18; its existing Copilot trial/PR and repair budget were left untouched.

The user's existing GitHub CLI OAuth login successfully started the read-only
task through the documented agent-tasks API. No ADO or new PAT was required.
The actual agent run checked out `5d1edb3ff1ff87eee8de860d4f0f61691e6b7b11`,
imported the registered MSAL-only setup, and read the original prepared manifest.
The legacy `Get-MsalSourceEvidence.ps1` filename is a forwarding shim to the
shared implementation, not another harness. This proves that MSAL handoff only;
package-selected IdWeb agent setup import is not proven. No evidence-aware
agent validation PASS, source update, independent review, or final update-PR
build is claimed from the probe.

Hosted tests exposed and fixed two harness tool issues: preserve the Windows
platform argument as an array, and use full-framework MSBuild for WinUI's legacy
CLR4 XAML compiler. No sample source, package or framework was changed. Both
default heads were verified unchanged. No merges, secrets, policies, tenant
settings, or automatic schedules were changed. MAUI builds, SDK unit tests and
live sign-in were NOT RUN. Unattended updates still require provenance resolution,
approved package-selected setup activation, and an actual reviewed update trial.

## Example Inventory

| Example | Existing authentication dependency | Shared harness release scope |
| --- | --- | --- |
| console-cli | Microsoft.Identity.Client 4.64.0 | Enabled; .NET 8 device code/silent |
| console-daemon | IdWeb.TokenCache 3.1.0; transitive MSAL use | Its existing IdWeb package only |
| desktop-winforms | Microsoft.Identity.Client 4.* | Enabled; .NET 8 Windows interactive/silent |
| desktop-winui | Microsoft.Identity.Client 4.* | Enabled; .NET 8 WinUI interactive/silent |
| desktop-wpf | Microsoft.Identity.Client 4.* | Enabled; .NET 8 Windows interactive/silent |
| spa-blazor-wasm | Microsoft.Authentication.WebAssembly.Msal 8.* | Excluded; browser MSAL, not MSAL.NET |
| web-api-azure-function | Functions SDK 4.4.0; Easy Auth | Excluded; no MSAL/IdWeb reference |
| web-api-obo-client | IdWeb/DownstreamApi 3.1.0 | Its existing IdWeb packages |
| web-api-obo-user | IdWeb/DownstreamApi 3.1.0 | Its existing IdWeb packages |
| web-api | IdWeb 3.7.1; .NET 9 bearer validation | Its existing IdWeb packages |
| web-app-aspnet | IdWeb/UI/DownstreamApi 3.8.0 | Its existing IdWeb packages |
| web-app-blazor-server | IdWeb/UI/DownstreamApi 3.1.0 | Its existing IdWeb packages |
| xplat-maui | Microsoft.Identity.Client 4.38.0 | Scoped; legacy .NET 6 Android/Windows; compatible build toolchain still required |

Package applicability is evaluated per sample. Never add MSAL.NET to an IdWeb-only
application or use an MSAL version as an IdWeb version. A transitive release does
not authorize a dependency override. Browser MSAL and Easy Auth remain excluded.

## One Source-Backed Update Process

For a specific release, use the same release workflow with `detect_latest=false`,
an existing `package`, exact `version`, matching official `release_notes_url`,
and empty `event_key`. For example, Microsoft.Identity.Client uses the MSAL.NET
tag URL; Microsoft.Identity.Web or Microsoft.Identity.Web.UI uses the IdWeb tag
URL. There is no separate SDK workflow or setup implementation.

`Get-MaintenanceSourceEvidence.ps1 -Package <package> -TargetVersion <version>`
prepares both exact source trees and scenario/source diffs in trusted hosted
setup. The schema-2 manifest records the package, official repository, target,
per-sample baselines, NuGet-recorded source commits, advisory tag observations,
package hashes, comparison hashes, and the required sourceProvenance policy.
`Validate-Maintenance.ps1 -Package <package>` checks that same evidence and the
applicable existing references. Package defaults remain MSAL-compatible for old
callers, but all agent tasks must pass the issue's explicit package.

Before a future agent session, a maintainer must set matching non-secret Agents
variables `MAINTENANCE_PACKAGE` and `MAINTENANCE_TARGET_VERSION`. The setup workflow
reads their imported environment values; repository Actions variables do not
configure a Copilot session. GitHub's repository Agents variables REST API is
`repos/{owner}/{repo}/agents/variables`, separate from Actions variables.
The workflow
also accepts explicit `package` and `target_version` inputs for a hosted smoke
test. A standalone smoke test does not prove agent setup import. There is no
automatic fallback version or concurrent-target agent setup. Missing/mismatched
configuration or evidence blocks editing rather than guessing.

For a maintainer-approved Web dependency-contract investigation, set the optional
Agents variable `MAINTENANCE_DEPENDENCY_SAMPLE` to the selected catalog id before
continuing its existing trial. A standalone hosted smoke instead accepts
`dependency_sample`. Setup transports this selector through
`inputs.dependency_sample || vars.MAINTENANCE_DEPENDENCY_SAMPLE`; an Agents process
environment fallback alone is insufficient during imported setup.

`Get-MaintenanceDependencyEvidence.ps1` supplements, but never overwrites, the
original primary manifest. It performs isolated package-only baseline and target
restores that preserve every original direct reference except the selected Web
version. It records both original assets graphs and resolves the corresponding
Microsoft.Identity.Abstractions packages. Each auxiliary source checkout is the
full commit declared by its official NuGet package in
`AzureAD/microsoft-identity-abstractions-for-dotnet`, never a moving branch or tag
substitute. Abstractions is auxiliary evidence, not a newly enabled direct update
target.

The supplement is `.maintenance-evidence/dependencies/manifest.json`, exported
as `MAINTENANCE_DEPENDENCY_MANIFEST`, and is SHA-bound to the primary manifest.
Normal evidence-aware validation automatically checks its original projects,
assets graphs, package hashes/metadata and clean source commits. A partial
supplement directory blocks validation. Setup additionally requires the original
sample project's hash; post-update validation still preserves unrelated direct
references. These graphs and inspected contracts do not prove runtime compatibility.
Agents must consume the original supplement, never regenerate it themselves.

The approved supplemental smoke
[45447581069](https://github.com/hossnrabbit/ms-identity-docs-code-dotnet/actions/runs/45447581069)
passed on `c4695a02357d5b0996ed22cef5c01a2272956e0f`, including real restores,
NuGet-pinned auxiliary source, integrity checks and a disposable Web 4.18.0 build
with DownstreamApi 3.1.0 retained and the original project restored. Its first
actual import attempt stopped correctly before planning because the selector was
not transported at setup time; the one-expression workflow repair at
`654bb109a09a534b2955eb329dc548893e9096f2` passed lint and its setup contract check.
These setup results alone are not an independently reviewed application update.

The existing planner, implementer, and reviewer work for either upstream. They
must compare public contracts, implementations, tests, parameters/defaults, and
scenario improvements across the sample's actual baseline and target, then make
justified package, source, and README edits within AGENTS.md. Package-only changes
need a completed discovery assessment. Do not force code churn when no applicable
source change is justified. Hosted CI includes the six IdWeb server samples as
well as the existing console and Windows clients. Legacy MAUI remains gated.

Current automation still stops at issue creation: automatic agent assignment is
disabled. Package-selected test-branch setup import and strict provenance remain
prerequisites for unattended code-update PRs. The live record above verifies
an actual reviewed Client sample update and its separate final hosted matrix;
the supplemented actual IdWeb trial remains blocked before editing. This is not unattended
rollout or evidence of live authentication behavior.

## Historical Prototype Setup (Not For This Test Branch)

The following describes the earlier MSAL-only default-branch prototype, not current
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
verifies NuGet-recorded commits in the expected official repository, and checks source/test
files and the manifest handoff in a separate Bash step. It writes the manifest to
`.maintenance-evidence/manifest.json` and exports `MAINTENANCE_SOURCE_MANIFEST` as a
convenience. The fixed repository-relative path does not depend on that environment
variable being available to the agent. Git ignores the entire evidence directory.

Setup requires the repository Agents variables `MAINTENANCE_PACKAGE` and
`MAINTENANCE_TARGET_VERSION` BEFORE starting a fresh session. Both the issue
package and target must match the prepared manifest and official upstream.
This is deliberately a single-target pilot, not concurrent multi-release routing.
The agent must not retry source acquisition or modify a prepared snapshot. Missing
or mismatched evidence is SETUP_BLOCKED and needs a setup repair/new session.

Use the hosted setup workflow, or the `source_package` and optional `source_target_version` inputs of
Maintenance validation, for source acquisition. Do not run local restores,
downloads, or builds where NuGet access is unavailable or forbidden.

The output directory must not already exist; the script refuses to overwrite a
snapshot. Use the printed manifest path. The script downloads official NuGet packages for
each applicable baseline and requested stable target, checks their repository commit
metadata, fetches the exact declared commits from the expected official repository,
records advisory tags, and creates temporary source worktrees plus a
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

A missing/invalid package commit, wrong repository metadata, unavailable declared
commit, or network access needed for the target
blocks setup globally. A baseline-only failure marks its samples setup-blocked,
omits that comparison, and prohibits edits to those samples; other verified
samples may proceed with an explicit PARTIAL result. Do not invent evidence,
change baseline metadata, or weaken verification to clear a blocker.

Historical MAUI tag-policy blocker (not a blocker under the new commit policy): the 4.38.0 tag resolves to
`876737608b6cc6caaead87751ed7aa43f57738fb`, while its NuGet repository commit is
`7d8a50263eac6dd7e52365c278774c6be7f82a10`. Under the new policy setup must fetch
the latter commit from the official repository; the tag difference is advisory.
MAUI changes still require verified source and a passing compatible build.
The harness does not install or modernize the sample's legacy .NET 6 MAUI toolchain.
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
./scripts/Validate-Maintenance.ps1 -Package Microsoft.Identity.Client -ExpectedVersion 4.91.1 -EvidenceManifest ./.maintenance-evidence/manifest.json -CheckOnly
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