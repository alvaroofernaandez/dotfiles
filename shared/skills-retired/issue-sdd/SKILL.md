---
name: issue-sdd
description: >
  Takes one or more GitHub issue numbers, fetches their full context, and drives
  a complete SDD cycle (explore → propose → spec → design → tasks) with production-safe
  implementation planning. Performs exhaustive codebase audits before any code change.
  Trigger: When user wants to plan, analyse, and implement a GitHub issue following SDD.
license: Apache-2.0
metadata:
  author: alvaroofernaandez
  version: "1.0"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, WebFetch, WebSearch, Agent
---

## Purpose

You are a **production-safe SDD orchestrator** specialised in GitHub issues.
You fetch the issue(s), audit the codebase exhaustively, and drive the full SDD
planning cycle — generating actionable tasks that can be implemented without
breaking production.

---

## Parameters

```
/issue-sdd <issue-number> [issue-number2 ...]
```

Examples:
```
/issue-sdd 558
/issue-sdd 541 542 543
```

---

## Execution Protocol

### Phase 0 — Preflight

1. For each issue number provided, run:
   ```bash
   gh issue view <N> --repo <owner/repo> --json title,body,labels,assignees,comments
   ```
2. Check that every issue has `status:approved` label.
   - If NOT approved: **stop** and tell the user — no code change should be planned for unapproved issues.
   - If approved (or it's a bug with `bug` label and the project allows it): proceed.
3. Search Engram for prior work:
   ```
   mem_search(query: "issue #<N> OR <title keywords>", project: "<project>")
   ```
4. Check SDD init: `mem_search(query: "sdd-init/<project>")` — run `/sdd-init` silently if missing.

### Phase 1 — Exploration (sdd-explore)

Delegate to `sdd-explore` sub-agent with:
- Full issue body + comments as context
- Keywords extracted from issue for targeted codebase search
- Instruction to use `code-review-graph` MCP tools FIRST (semantic_search_nodes, query_graph, get_impact_radius) before Grep/Read
- Production-safety mandate: identify what currently works and MUST NOT break

The exploration MUST cover:
- Exact files and functions involved in the bug/feature
- Current data flow end-to-end
- Existing tests that cover the affected paths
- Any related issues or PRs referenced
- Risk map: what breaks if X changes

### Phase 2 — Proposal (sdd-propose)

Delegate to `sdd-propose` sub-agent with exploration output.

The proposal MUST include:
- Root cause (for bugs) or user value (for features)
- Chosen approach with explicit tradeoffs vs alternatives
- Production-safety strategy: feature flags, backward-compatible changes, migration plan if needed
- Scope boundaries: what is IN and OUT of this change

### Phase 3 — Spec (sdd-spec)

Delegate to `sdd-spec` sub-agent with proposal.

Spec MUST include:
- Acceptance criteria mapped 1:1 to issue requirements
- Edge cases and error scenarios
- Regression scenarios: existing behaviour that must still pass

### Phase 4 — Design (sdd-design)

Delegate to `sdd-design` sub-agent with proposal + spec.

Design MUST include:
- Exact files to modify (no "probably" — verified against codebase)
- Contracts that change (DTOs, enums, interfaces)
- Zero breaking changes guarantee or explicit migration steps

### Phase 5 — Tasks (sdd-tasks)

Delegate to `sdd-tasks` sub-agent with spec + design.

Tasks MUST be:
- Ordered by dependency (nothing assumes something not yet done)
- Each independently verifiable
- Flagged with risk level: 🟢 safe / 🟡 review needed / 🔴 high risk
- Sized for chained PRs if total > 400 changed lines

### Phase 6 — Summary

Return to user:
- One-paragraph executive summary
- Link(s) to the issue(s)
- Ordered task list with risk flags
- Next action: "Ready to run `/sdd-apply`?"

---

## Production-Safety Rules (MANDATORY)

These rules apply to every delegation in this skill:

1. **Audit before touch**: never propose editing a file without first reading it and understanding its full context.
2. **Test coverage first**: check existing tests before adding code. If there are no tests for the affected path, add them as a task BEFORE the implementation task.
3. **No regressions**: every task list must include a "run existing tests" checkpoint after each risky change.
4. **Backward-compatible contracts**: DTOs, enums, and HTTP contracts must not break existing consumers without a migration task.
5. **Smallest possible change**: prefer targeted fixes over refactors. Don't clean up what doesn't need cleaning.
6. **One concern per task**: a task that touches auth AND persistence AND UI is too big — split it.

---

## Model Assignments

| Phase | Model |
|-------|-------|
| Orchestrator (this skill) | opus |
| sdd-explore | sonnet |
| sdd-propose | opus |
| sdd-spec | sonnet |
| sdd-design | opus |
| sdd-tasks | sonnet |

---

## Artifact Store

Default: `engram`. Pass `artifact_store.mode: engram` to all sub-agents.
Use `openspec` only if user explicitly requests file artifacts.

---

## Error Handling

- Issue not found: stop, show `gh` error, ask user to verify repo and number.
- No `status:approved`: stop, quote the label requirement, link to issue.
- SDD init missing: run silently, then continue.
- Engram unavailable: proceed with `artifact_store.mode: none`, warn user that artifacts won't persist.
