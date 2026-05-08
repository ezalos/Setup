---
name: notify-louis
description: Use when stuck on a blocker that needs Louis's action (credential, decision, manual step), when ≥2 reasonable paths require Louis's call, OR when Louis explicitly said "notify me when done" earlier in the conversation. Sends a Telegram message and ends the turn for blockers/guidance.
---

# notify-louis

Ping Louis on Telegram for the narrow set of moments where the session genuinely cannot proceed — or when he explicitly asked to be told when long work finished. Everything else stays in the terminal.

## When to fire

Fire **only** for these three cases:

- **🚫 blocker** — cannot proceed without Louis. Examples: OAuth token / password / credential needed; physical action required (plug in a device, flip a switch); destructive op awaiting approval; external resource locked by another process.
- **❓ guidance** — there are ≥2 reasonable paths and the choice would meaningfully reshape the work. Not for minor style preferences or questions Claude can answer itself.
- **✅ done** — only when Louis explicitly said "notify me when done" / "ping me when it's ready" / similar earlier in the conversation. **No implicit detection** of "this seems like a long task."

## When NOT to fire

- Routine permission prompts when there's an active terminal session — the prompt already shows up where Louis is.
- Questions Claude can answer itself.
- Every multi-step task, just because it has multiple steps.
- Mid-work status updates.

## How to fire

Run the helper script with one of `blocker`, `guidance`, or `done` and a one-line reason:

```bash
~/.claude/skills/notify-louis/notify.sh blocker "Need GitHub OAuth token to push the PR branch."
~/.claude/skills/notify-louis/notify.sh guidance "Two valid migration paths — destructive vs additive. Which?"
~/.claude/skills/notify-louis/notify.sh done "Refactor complete, 47/47 tests green, ready to review."
```

The script gathers tmux session/window and cwd automatically and includes a `ta '<session>:<window>'` line so Louis can jump straight back into the right pane.

## After firing

- After **🚫 blocker** or **❓ guidance** — end the turn. You're blocked by definition; don't keep working on assumptions.
- After **✅ done** — continue or end naturally; the ping is informational.

## Failure modes

The script exits non-zero if Telegram is misconfigured or the API call fails:

| exit | meaning |
|------|---------|
| 1    | bad/missing args |
| 2    | telegram not configured (no `.env` or token unset) — run `/telegram:configure` |
| 3    | empty allowlist — run `/telegram:access pair` |
| 4    | Telegram API error (full JSON on stderr) |
| 5    | `jq` missing |

If the script exits non-zero, **don't pretend the ping went through**. Surface the failure to Louis in the terminal instead.

## Dry run

Set `NOTIFY_DRY_RUN=1` to print the composed message to stdout without hitting the network. Useful for iterating on wording.
