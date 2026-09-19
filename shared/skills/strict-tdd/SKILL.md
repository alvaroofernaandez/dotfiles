---
name: strict-tdd
description: >
  The full strict-TDD contract: RED/GREEN/REFACTOR discipline, per-layer scope
  (backend, frontend, infra), the setup-first rule for projects with no runner,
  the [tdd-gate] pre-flight block, why after-the-fact tests are forbidden, and
  how this interacts with SDD. Invoke when starting any feature, bug fix or
  behavioural refactor, or when a project has no test runner configured yet.
---

## Strict TDD (MANDATORY for ALL projects — frontend AND backend)

This rule is **STRICT** and **BLOCKING** across every project, every language, every layer. There is no "TDD only when the project supports it" — if a project doesn't support TDD yet, you set it up first, then write code.

### Iron law

For ANY new feature, bug fix, refactor with behavioral changes, or any code touching logic:

1. **RED** — write the failing test first. The test MUST fail for the right reason (assertion failure, not import error).
2. **GREEN** — write the minimum code that makes the test pass. Nothing more.
3. **REFACTOR** — clean up while keeping the test green.

Never invert this order. Never write the implementation first and "add tests later". "Later" never comes; this is non-negotiable.

### Scope (no exceptions)

- **Backend**: APIs, services, domain logic, data access, jobs, scripts → unit + integration tests via the project's runner (pytest, jest, vitest, go test, etc.).
- **Frontend**: components, hooks, stores, utilities, page logic → unit/component tests via the project's runner (vitest + RTL, jest + RTL, etc.). E2E with Playwright for critical user flows.
- **Infra/Scripts**: if logic is non-trivial, write tests. If truly one-shot and disposable, document why no test exists.

### Setup-first rule

If a project has no test runner configured, your FIRST commit in that project is to bootstrap one (install deps, add config, write one passing smoke test). Only then do you start the requested work — RED → GREEN → REFACTOR.

### Pre-flight check (emit before any implementation)

Before writing implementation code, emit a `[tdd-gate]` block:

```
[tdd-gate]
Runner: <pytest | vitest | jest | go test | …>
RED test: <path/to/test_file::test_name — what it asserts and why it must fail now>
```

If you cannot fill this block honestly, you are not allowed to write implementation code yet.

### After-the-fact tests are forbidden

Writing the code first and then "covering it with tests" is NOT TDD. It is regression testing of code you already trust — which means you skipped the design feedback that TDD provides. Do not do this. If you catch yourself doing it, STOP, delete the implementation, and restart from RED.

### Interaction with SDD

- The SDD `strict_tdd` flag in `sdd-init` is a project-level enforcement. This global rule is stricter: TDD is on by default for ALL projects, SDD or not.
- When SDD is active, the `sdd-apply` agent already enforces TDD. This rule extends that enforcement to every other task (non-SDD changes, quick fixes, scripts).
