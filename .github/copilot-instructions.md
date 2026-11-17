# Scenario Maintenance and Improvement

For MSAL maintenance issues, follow root AGENTS.md and the process in
.github/agents/sample-implementer.agent.md, including when the task starts with
the default Copilot agent. READ `.maintenance-evidence/manifest.json` and its
setup-prepared local SDK source trees before invoking the read-only sample-planner.
Use scripts/maintenance-samples.json to inventory all examples; only its five
direct-msal-net samples are editable for Microsoft.Identity.Client releases.
IdWeb, transitive daemon, browser MSAL, and Easy Auth samples are excluded.
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