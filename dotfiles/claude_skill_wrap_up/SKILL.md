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

Review what was learned this session. For each piece of knowledge, choose
a destination tier per the framework:

| Tier               | Path                                                | Use for                                                                |
|--------------------|-----------------------------------------------------|------------------------------------------------------------------------|
| Auto memory        | `~/.claude/projects/<project>/memory/`              | Patterns Claude discovered, project quirks, debugging insights         |
| Project CLAUDE.md  | `<repo>/CLAUDE.md`                                  | Permanent project rules, conventions, commands, architecture           |
| Project rules      | `<repo>/.claude/rules/<topic>.md` (with `paths:`)   | Topic-specific instructions scoped to file types                       |
| CLAUDE.local.md    | `<repo>/CLAUDE.local.md`                            | Personal WIP context, sandbox creds, current focus (not committed)     |
| `@import`          | reference in CLAUDE.md                              | Cross-reference rather than duplicate                                  |

### Confidence-gated auto-apply

For each knowledge item:

- **High confidence** (one tier clearly fits per the table): auto-apply,
  list under "Applied" in the summary.
- **Low confidence** (≥2 tiers plausibly fit, OR user intent didn't
  clearly indicate scope): auto-apply *the chosen tier* but list under
  "Review please" in the summary so Louis can quickly relocate.

Heuristics for "low confidence":
- Could be project-wide OR file-type-scoped (CLAUDE.md vs `.claude/rules/`)
- Could be permanent OR ephemeral (CLAUDE.md vs CLAUDE.local.md)
- Refers to something cross-cutting

When low confidence, log:

```
claude-log wrap-up WARNING "wrap-up: ambiguous memory placement for <topic>; chose <tier>"
```

## Phase 3: Review & Apply

Analyze the conversation for self-improvement findings. **Auto-apply all
actionable findings immediately**; do not gate per-finding.

If the session was short or routine with nothing notable, output
"Nothing to improve" in the summary and log:

```
claude-log wrap-up INFO "wrap-up: no self-improvement findings"
```

…then proceed to Phase 4.

### Finding categories

- **Skill gap** — Claude struggled, got wrong, needed multiple attempts.
- **Friction** — Repeated manual steps, things Louis had to ask explicitly that should have been automatic.
- **Knowledge** — Facts Claude didn't know but should have.
- **Automation** — Repetitive patterns that could become skills, hooks, or scripts.

### Action types

- **CLAUDE.md** — edit relevant project or global CLAUDE.md.
- **Rules** — create or update `<repo>/.claude/rules/<topic>.md`.
- **Auto memory** — append insight to the project's auto-memory.
- **Skill self-improvement** — edit the SKILL.md of any skill that ran in this session if user feedback or caveats during its execution would have led to better behavior. Examples: a missed trigger phrase in the description; an action the skill should have taken automatically but Louis had to ask for; a step that fired in the wrong order; a guard that should have prevented something. Treat user corrections (the universal-baseline WARNING events for the relevant skill) as the primary signal. Edit the SKILL.md inline; commit per the regular Phase 1 flow.
- **New skill / Hook spec** — write a spec to `~/Setup/docs/plans/YYYY-MM-DD-<name>-design.md`. Do NOT auto-build the new skill.
- **CLAUDE.local.md** — create or update per-project local memory.

**Capture the trigger source.** When applying a skill self-improvement, note in the summary what user input prompted it ("Louis said X mid-execution → updated skill Y to do Z automatically"). This makes the audit trail readable and gives Louis a chance to push back if the change misread his feedback.

### Summary format (for the consolidated report)

```
Findings (applied):

1. ✅ Skill gap: <description>
   → [CLAUDE.md] <what was added>

2. ✅ Knowledge: <description>
   → [Rules] <file>

3. ✅ Automation: <description>
   → [Skill spec] <path-to-new-spec.md>

4. ✅ Skill self-improvement: <skill-name>: <trigger from user input>
   → [SKILL.md] <what was edited>

---
No action needed:

5. <description>
   <reason — already documented / out of scope / etc.>
```

## Phase 4: Publish It

After all other phases complete, review the full conversation for
publishable material:

- Interesting technical solutions or debugging stories.
- Community-relevant announcements or updates.
- Educational content (how-tos, tips, lessons learned).
- Project milestones or feature launches.

### If publishable material exists

Create a per-post directory under `~/Drafts/`:

```bash
mkdir -p ~/Drafts/<post-slug>
```

Where `<post-slug>` is a kebab-case version of the working title.

Write tailored drafts for each platform:

- `~/Drafts/<post-slug>/Reddit.md` — tldr at top, then full-post structure
- `~/Drafts/<post-slug>/Blog.md` — long-form with section headings

Platforms supported in v1: **Reddit, Blog**. (To add more — HN,
Mastodon, X, etc. — extend this list.)

In the consolidated report, present:

```
Potential content to publish:

1. "<Title of post>" — 1-2 sentence description.
   Drafts: ~/Drafts/<post-slug>/Reddit.md, Blog.md

(Drafts written. No posting happens automatically — paste manually
when ready.)
```

If multiple publishable items: write all drafts. Note the most
time-sensitive one in the summary; do NOT post automatically.

### If nothing publishable

Output `Nothing worth publishing from this session.` in the summary and log:

```
claude-log wrap-up INFO "wrap-up: no publishable content this session"
```

## Final consolidated report

After all four phases complete, present this single report as the final
output of the skill:

````
# Wrap-up — YYYY-MM-DD HH:MM

## Phase 1 — Ship It
- Committed: <repos and short subjects>
- Pushed: <repos>  (or "none")
- File placement: <fixes>  (or "no changes needed")
- Deploy: <ran X / failed: ... / skipped (no marker)>
- Tasks: <N completed, M flagged orphaned>

## Phase 2 — Remember It
Applied (high-confidence):
- [<tier>] <summary>

Review please (low-confidence — applied to <tier>, may want relocation):
- <summary>  (or "none")

## Phase 3 — Review & Apply
Applied:
1. <category>: <description> → [<tier>] <action>

No action needed:
2. <description> — <reason>

## Phase 4 — Publish It
- <Title>: drafted at ~/Drafts/<slug>/  (or "Nothing worth publishing")

## Self-observability
<count> entries written to ~/.claude/lessons.md this run.
````

The `<count>` is the number of `claude-log wrap-up` lines that landed
in `~/.claude/lessons.md` during this run — verify by:

```bash
# Replace YYYY-MM-DD with today's date
grep -c "^$(date +%Y-%m-%d) wrap-up " ~/.claude/lessons.md
```

(Subtract any that were already there before this run started.)
