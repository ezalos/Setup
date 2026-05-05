---
name: wrap-up
description: Use when Louis says "wrap up", "close session", "end session", "wrap things up", "close out this task", or invokes /wrap-up. Runs end-of-session checklist for shipping, memory, and self-improvement. Auto-applies routine actions, gates ambiguous memory placements for review, and produces one consolidated report.
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill, AskUserQuestion, TaskCreate, TaskUpdate, TaskList
---

# Session Wrap-Up

Run four phases in order. Each is conversational and inline — no separate
documents. All phases auto-apply (with the confidence gate in Phase 2).
Present one consolidated report at the end.

## Observability

This skill follows the universal observability baseline (see
`docs/plans/2026-04-21-skill-storage-observability-design.md`).

**Universal baseline:** CRITICAL on abort, WARNING on correction/fallback/retry/precondition-fail, INFO on edge path.

**Skill-specific triggers:**

| Level    | Trigger                                                    | Message template                                          |
|----------|------------------------------------------------------------|-----------------------------------------------------------|
| CRITICAL | Phase 1 commit/push fails                                  | `wrap-up: phase1 ship failed in <repo>: <reason>`         |
| CRITICAL | Phase 1 deploy command exits non-zero                      | `wrap-up: deploy failed in <repo>: <stderr-tail>`         |
| WARNING  | Low-confidence memory placement (Phase 2)                  | `wrap-up: ambiguous memory placement for <topic>; chose <tier>` |
| WARNING  | Phase 1 file rename collision                              | `wrap-up: file rename collision: <from> -> <to>`          |
| WARNING  | Task flagged orphaned (>2 sessions stale)                  | `wrap-up: orphaned task <id>: <subject>`                  |
| INFO     | No deploy marker in repo                                   | `wrap-up: no deploy marker in <repo>; skipped`            |
| INFO     | Nothing publishable                                        | `wrap-up: no publishable content this session`            |
| INFO     | Nothing to improve                                         | `wrap-up: no self-improvement findings`                   |

Log via the `claude-log` helper script — concrete invocations look like:

```
claude-log wrap-up INFO "wrap-up: started"
claude-log wrap-up WARNING "wrap-up: ambiguous memory placement for <topic>; chose <tier>"
claude-log wrap-up CRITICAL "wrap-up: deploy failed in <repo>: <stderr-tail>"
```

# triggers I might have missed: subagent failures during phase execution, partial-session crashes

## Phase 1: Ship It

(populated in Task 5)

## Phase 2: Remember It

(populated in Task 6)

## Phase 3: Review & Apply

(populated in Task 7)

## Phase 4: Publish It

(populated in Task 8)

## Final consolidated report

(populated in Task 9)
