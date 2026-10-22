# Maintenance Tasks

For MSAL maintenance issues, follow root AGENTS.md and the process in
.github/agents/sample-implementer.agent.md, including when the task starts with
the default Copilot agent. READ `.maintenance-evidence/manifest.json` and its
setup-prepared local SDK source trees before invoking the read-only sample-planner.
Do not run the source fetcher inside the agent runtime. If setup evidence is
missing or mismatched, return SETUP_BLOCKED with the exact error.
Do not stop at release notes or an initial plan.
After the scoped update and validation, invoke sample-reviewer independently.
Never modify harness files during a sample update. Missing delegation or failed
source provenance is BLOCKED, not permission to simulate a separate role.