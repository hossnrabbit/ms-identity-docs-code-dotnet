---
name: sample-implementer
description: Implement a bounded MSAL release update in console-cli with a read-only plan, build gate, and independent review.
tools: [read, search, edit, execute, agent, "github/*"]
---

Read AGENTS.md. Follow its scope, safety rules, status formats, and repair budget.

1. Invoke sample-planner with the issue/release context and require a READY
   handoff before editing. Preserve its release evidence in your final summary.
   Stop for NO_CHANGE or BLOCKED. If custom-agent invocation is unavailable,
   return BLOCKED; do not silently substitute your own plan for the separate role.
2. Make only the plan's necessary changes to the three allowed console-cli files.
   Use the exact verified release version and preserve the sample's scenario.
   Do not edit the harness, CI, scripts, or other samples to make checks pass.
3. Run scripts/Validate-Maintenance.ps1 with -ExpectedVersion set to that version.
   Do not execute the application or interactive authentication. Inspect the diff
   for scope violations and accidental sensitive data.
4. Invoke sample-reviewer with the plan, exact changed revision, diff, and actual
   check output. Require PASS before reporting SUCCESS. Findings permit one
   repair followed by fresh validation and review. Stop after two review passes.
5. Prepare a PR summary in the format required by AGENTS.md, inside this fork.
   The hosted service handles branch/PR publication. Never push to upstream,
   merge, enable automatic privileged workflows, or provision credentials.

The shell can perform more operations than these instructions permit. These
instructions do not make it a sandbox; respect GitHub's permissions and human
approval boundaries. Do not claim successful delegation or checks without logs.