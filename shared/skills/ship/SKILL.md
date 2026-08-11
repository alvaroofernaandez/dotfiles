---
name: ship
description: >
  End-to-end delivery of a working diff: group changes into reviewable work units,
  commit them with conventional messages, split into chained PRs when the diff exceeds
  the review budget, self-review before publishing, and open a fully documented PR.
  Orchestrates work-unit-commits, chained-pr, prs-pro and pr-review in one pass so the
  decision of "which skill do I invoke now" disappears.
  Trigger: when the user says "ship it", "sube esto", "haz el PR", "commit y PR",
  "prepara esto para review", or asks to take finished work from working tree to open PR.
---

# ship — working tree to reviewed PR, in one pass

You are the orchestrator of the delivery pipeline. The individual skills already exist
and are good; what was missing is the order, the gates, and the decisions between them.
Do NOT reimplement what those skills do — invoke them and enforce the gates.

## Non-negotiables

- **Never** add `Co-Authored-By` or any AI attribution to commits.
- **Conventional commits only** (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`).
- **Never commit directly to the default branch.** If HEAD is on `main`/`master`, branch first.
- Commit or push **only** when the user asked for it. `ship` is that ask.
- Artifacts (commit messages, PR body, code comments) are written in **English**,
  regardless of the conversation language.

## Pipeline

### 0. Preflight — abort early, not halfway

```bash
git rev-parse --abbrev-ref HEAD          # current branch
git status --porcelain                   # is there anything to ship?
git diff --stat && git diff --cached --stat
```

Stop and report if: no changes to ship, unresolved merge conflicts, or a detached HEAD.

If on the default branch, create a branch named from the change itself
(`feat/short-slug`, `fix/short-slug`) before touching anything.

### 1. Measure the review budget — this decides the whole shape of the run

```bash
# PRODUCTION lines only: test files never count toward the budget.
git diff --numstat <base>...HEAD | grep -vE '(test|spec|__tests__|\.test\.|\.spec\.)' \
  | awk '{a+=$1; d+=$2} END {print a+d}'
```

- **≤ 400 production lines** → single PR. Continue to step 2.
- **> 400 production lines** → invoke the `chained-pr` skill and split into stacked slices.
  Each slice must stand on its own: it compiles, its tests pass, and it is reviewable
  without the ones that follow. Then run steps 2–5 **per slice**.

Announce the decision explicitly before proceeding. Never silently ship an oversized PR.

### 2. Group into work units — invoke `work-unit-commits`

A work unit is one coherent, reviewable change: the code, its tests, and its docs
travel **together** in the same commit. Never a "code" commit followed by a "tests" commit.

Reject these groupings:
- one commit per file
- a commit that mixes an unrelated refactor with a feature
- tests split away from the code they cover

### 3. Commit

Write conventional messages whose body answers **why**, not what — the diff already
says what. Stage per work unit (`git add <paths>`), never `git add -A` blindly.

### 4. Self-review BEFORE publishing — this is the gate that earns its keep

Re-read your own diff as a hostile reviewer. Invoke `pr-review` against the branch diff.
For high-risk changes (auth, payments, migrations, deletions, anything touching money
or user data) escalate to `judgment-day` for adversarial dual review.

Fix what the review confirms, then re-run. Only proceed when it comes back clean.
**Publishing a PR you have not reviewed yourself is how you waste a reviewer's time.**

### 5. Open the PR — invoke `prs-pro`

`prs-pro` writes the description: diagrams, root-cause analysis, commit breakdown,
test plan. Do not hand-roll a PR body when that skill exists.

If the repository belongs to Gentle AI, invoke `branch-pr` instead — it carries the
issue-first checks that org requires.

End the PR body with:

```
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Reporting back

Report what actually happened, in this shape:

```
branch    feat/user-export
budget    287 production lines (under 400 — single PR)
commits   3 work units
review    pr-review clean after 1 fix (null guard in export handler)
PR        #142 https://github.com/org/repo/pull/142
```

If a step was skipped, say which and why. If the review found something you could not
fix, open the PR as a draft and say so — do not present incomplete work as finished.

## What this skill deliberately does NOT do

- It does not merge. Merging stays a human decision.
- It does not force-push or rewrite published history.
- It does not create the issue. Use `issue-creation` first if the repo requires one.
