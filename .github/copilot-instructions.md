# Scenario Maintenance and Improvement

For MSAL maintenance issues, follow root AGENTS.md and the process in
.github/agents/sample-implementer.agent.md, including when the task starts with
the default Copilot agent. READ `.maintenance-evidence/manifest.json` and its
setup-prepared local SDK source trees before invoking the read-only sample-planner.
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