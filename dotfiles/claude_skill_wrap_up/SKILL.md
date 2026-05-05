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

### 1a. Commit

For each repo directory touched during this session:

1. Run `git status --porcelain` in that repo.
2. If output is empty: skip — repo is clean.
3. If non-empty:
   - Inspect the diff (`git diff` and `git diff --cached`) to draft a one-line commit subject summarizing the change.
   - Stage relevant files explicitly (avoid `git add -A` — never commit secrets or unrelated dirty work).
   - Commit on the default branch (`master` for Louis's own repos; check `git symbolic-ref --short HEAD` first).
   - **Do NOT use `--no-verify`.** If a hook fails, treat it as a precondition failure: log `WARNING wrap-up: phase1 hook failed in <repo>: <hook-name>`, leave the commit unmade, and report in the final summary.
4. **Push policy:** push only if (a) the user explicitly asked for pushes during this session, OR (b) the repo's CLAUDE.md frontmatter has `auto-push: true`. Otherwise leave un-pushed and report.

If a commit or push fails for non-hook reasons (network error, etc.), log:

```
claude-log wrap-up CRITICAL "wrap-up: phase1 ship failed in <repo>: <reason>"
```

### 1b. File placement check

For each file created or modified during this session:

1. **Naming.** If the project has a CLAUDE.md with naming conventions, check the file matches; otherwise infer from neighbor files (snake_case vs kebab-case). If a violation is found, rename via `git mv`.
2. **Location.** If the file is misplaced (e.g., a test file in `src/`, a doc in the project root), move it to the correct subfolder.
3. **Document files** (.md, .docx, .pdf, .xlsx, .pptx) created at the workspace root or in a code directory: move to `docs/` if a `docs/` folder exists.

On a rename collision (target name already exists), log:

```
claude-log wrap-up WARNING "wrap-up: file rename collision: <from> -> <to>"
```

…and leave the file in place; report in summary.

### 1c. Deploy

Detect a deploy step by checking, in order, the FIRST match:

1. `Makefile` containing a `deploy:` target → run `make deploy`
2. `scripts/deploy.sh` (executable) → run `scripts/deploy.sh`
3. `bin/deploy` (executable) → run `bin/deploy`
4. Project `CLAUDE.md` containing `## Deploy` followed by a fenced bash code block → run that block's first command

If a marker matched: run the command. Capture stdout/stderr.
- On exit 0: report `Deploy: ran <command>` in summary.
- On non-zero exit: log:

  ```
  claude-log wrap-up CRITICAL "wrap-up: deploy failed in <repo>: <stderr-tail>"
  ```

  Report in summary, but DO NOT abort wrap-up — proceed to subsequent phases.

If NO marker matched: log:

```
claude-log wrap-up INFO "wrap-up: no deploy marker in <repo>; skipped"
```

…and report `Deploy: skipped (no marker)` in summary. **Do NOT ask the user about manual deployment.**

### 1d. Task cleanup

1. Run TaskList. Read all tasks.
2. For tasks completed during this session but still `pending` or `in_progress`: TaskUpdate to `completed`.
3. For tasks `pending` for ≥2 sessions without progress: mark them as orphaned in the summary. Do NOT auto-delete. Log:

   ```
   claude-log wrap-up WARNING "wrap-up: orphaned task <id>: <subject>"
   ```

## Phase 2: Remember It

(populated in Task 6)

## Phase 3: Review & Apply

(populated in Task 7)

## Phase 4: Publish It

(populated in Task 8)

## Final consolidated report

(populated in Task 9)
