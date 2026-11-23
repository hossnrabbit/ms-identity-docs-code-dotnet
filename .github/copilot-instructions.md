# Scenario Maintenance and Improvement

For MSAL.NET or IdWeb maintenance issues, use ONE shared harness. Follow root AGENTS.md and the process in
.github/agents/sample-implementer.agent.md, including when the task starts with
the default Copilot agent. READ `.maintenance-evidence/manifest.json` and its
setup-prepared local SDK source trees before invoking the read-only sample-planner.
Use scripts/maintenance-samples.json and Select-MaintenanceSamples to select
only existing direct references to the requested package. Microsoft.Identity.Client
uses the five direct clients; Microsoft.Identity.Web packages use their existing
references in the six server samples, including the daemon. Browser MSAL and
Easy Auth remain excluded. Never introduce a dependency or turn a transitive MSAL
release into an IdWeb bump. Preserve unrelated package references.
Require the schema-2 package, official upstream repository, and exact target
with sourceProvenance `nuget-repository-commit` (exact package-backed commits;
release tags are advisory, never substitute source or block on tag differences)
to match the task and the MAINTENANCE_PACKAGE/MAINTENANCE_TARGET_VERSION setup
configuration. Pass the explicit requested -Package to Validate-Maintenance.ps1.
Schema-2 evidence records each original reference, resolved baseline, target,
and status. Use the matching comparisons entry, never another sample's baseline.
Preserve newer/setup-blocked samples and report reasons. Report PARTIAL when
requested samples are blocked or changed samples lack passing platform builds.
When local NuGet access/builds are unavailable or forbidden, use offline checks
and report builds NOT RUN rather than trying restores or toolchain installs.
Supply each comparison's sourceDiffs paths/coverage to the planner. Setup prepares
scenario-apis.diff and sdk-client.diff for direct file reads in bounded ranges.
NEEDS_EVIDENCE is an intermediate handoff: supply the requested patch sections
or focused read-only git diff output and reinvoke the planner. Do not stop solely
because the planner lacks execute access; do not simulate its completed plan.
Do not run the source fetcher inside the agent runtime. If setup evidence is
missing or mismatched, return SETUP_BLOCKED with the exact error.
Require scenario improvement discovery before deciding whether code needs changes:
compare relevant public parameters (including optional/default values), overloads,
builders/options, and behavior beyond calls already used. Critically assess
existing code. Require the AGENTS.md scenario improvement matrix, source/test
evidence, candidate decisions, and per-improvement validation limitations.
Do not equate compilation or compatible calls with correctness or absence of
useful improvements. A package-only update or NO_CHANGE needs that assessment.
Implement justified improvements within the approved scenario/files; defer scope
expansions for maintainer approval. Do not force adoption of every new API.
Do not stop at release notes or an initial plan.
After the scoped update and validation, invoke sample-reviewer independently.
Never modify harness files during a sample update. Missing delegation or failed
source provenance is BLOCKED, not permission to simulate a separate role.