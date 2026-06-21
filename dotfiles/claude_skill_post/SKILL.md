---
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
description: Interview-driven LinkedIn/X post writer in Louis's voice. Triggered by /post linkedin or /post x. Reads $SOCIAL_HOME/voice/<platform>.md, runs a 5-question interview, generates 5 hooks, drafts a full post, iterates with Louis, then writes to $SOCIAL_HOME/drafts/YYYY-MM-DD-slug-<platform>.md.
---

# /post — Post writer

## Trigger
`/post linkedin` or `/post x`

## Inputs

- `$SOCIAL_HOME` env var (fallback: `$HOME/social`)
- Platform arg: `linkedin` or `x`
- `$SOCIAL_HOME/voice/<platform>.md` (required — error if missing)

## Workflow

### Step 1: Resolve paths

Read `$SOCIAL_HOME`. Default to `$HOME/social` if unset (warn).

Verify `$SOCIAL_HOME/voice/<platform>.md` exists. If missing:
```
voice/<platform>.md not found. Run /audit <platform> first to generate it.
```
Stop.

### Step 2: Read voice rules

Read `$SOCIAL_HOME/voice/<platform>.md` fully. Internalise format, tone, hook patterns, structure, vocabulary, what-to-avoid, endings.

### Step 3: Interview

Ask one question at a time via AskUserQuestion. Capture answers.

| # | Field    | Options                                                   |
|---|----------|-----------------------------------------------------------|
| 1 | Goal     | Build authority / Inspire / Convert / Entertain / Document |
| 2 | Media    | Text-only / Image(s) / Carousel / Video                   |
| 3 | Message  | (free-text) raw idea — lesson, opinion, story, result    |
| 4 | Emotion  | Curiosity / Urgency / Agreement / Awe / Resonance         |
| 5 | Audience | (free-text) specifically who? not "everyone"             |

If Media = Video, ask a follow-up: "Paste transcript or key points (3-5 bullets)."

### Step 4: Generate 5 hooks

Apply hook patterns from `voice/<platform>.md` to the message + audience + emotion. Output:

```
Hook 1 — [Pattern name]
[Hook text — one or two lines]
Rationale: [Why this hook, tied to a specific pattern from voice rules]

Hook 2 — ...
```

Use AskUserQuestion: "Which hook do you want to build the post around?" (Options: 1, 2, 3, 4, 5, Regenerate, Edit one inline.)

If Regenerate: generate 5 new hooks (different patterns), repeat.
If Edit: ask which hook, accept the edited text, use that.

### Step 5: Draft the full post

Build the post around the chosen hook applying every voice rule from `voice/<platform>.md`:
- Length within the documented range
- Signature formatting (Unicode bold sections, bullet hierarchy, etc.)
- Tone matching documented confidence/language conventions
- Structure: opener (the hook) → context → bullets → reflection → gratitude (if applicable) → CTA → hashtags (LinkedIn) or nothing (X)
- Avoid every pattern in "What to avoid"

Output the full draft.

### Step 6: Iterate

Loop:
- User says "tighter" / "more numbers" / "rewrite the open" / "less formal" / etc. → apply targeted edit, show new draft.
- User says "ship it" → proceed to step 7.
- User says "scrap" → stop, no file written.

### Step 6.5: Citation hard-check (BLOCKING — do not skip)

Louis's rule: **no factual claim ships without a source.** This gate runs after "ship it"
and before saving. A draft cannot reach `status: ready` with an unresolved factual claim.

1. **Extract every factual claim** from the approved body. A factual claim is any
   externally verifiable statement — types: `number | named-stat | company-fact |
   benchmark | pricing | forecast | historical-event`, plus any claim about what a named
   person or org did/said. Use the rubric in
   `~/.claude/skills/cite/references/sourcing-standards.md` §1. Scope = **everything
   factual** (strict). Pure first-person experience or opinion ("I'm proud", "I taught a
   class") is NOT a factual claim and needs no source.

2. **Source + verify each claim** by calling the existing cite scripts directly (no full
   /cite orchestration needed):
   ```bash
   python3 ~/.claude/skills/cite/scripts/tavily_cli.py search "<claim>"      # find candidates
   python3 ~/.claude/skills/cite/scripts/tavily_cli.py extract <url>         # fetch page text
   python3 ~/.claude/skills/cite/scripts/validate_claim.py <claim.yaml> <page.txt>  # verbatim / anti-fabrication
   python3 ~/.claude/skills/cite/scripts/tier_lookup.py <domain>             # authority tier (1–4 ok)
   python3 ~/.claude/skills/cite/scripts/decisions.py recency <date>
   python3 ~/.claude/skills/cite/scripts/decisions.py status <tier> <recency>
   ```
   A claim **passes** when it has a healthy-link source of `tier` 1–4 whose page text
   actually supports the value (value_match / validate_claim agree).

3. **BLOCK on any claim that fails.** Present the failing claims via AskUserQuestion. For
   each, Louis chooses:
   - **Add source** — he pastes a URL; re-verify it through the scripts above.
   - **Soften** — reword so the line is no longer a verifiable claim; then re-extract.
   - **Waive** — explicit, recorded override (capture the reason).
   Do not save until every factual claim is sourced, softened, or explicitly waived.

4. **Build the first-comment block** — the sources comment Louis pastes as the first
   comment under the post (platforms don't render footnotes):
   ```
   ----- FIRST COMMENT (sources) -----
   Sources:
   [1] <claim, short> — <url>
   [2] ...
   ```

### Step 7: Slugify and save

Generate slug from message: lowercase, dash-separated, ≤6 words.

Filename: `$SOCIAL_HOME/drafts/<YYYY-MM-DD>-<slug>-<platform>.md`

Write with frontmatter:

```yaml
---
platform: <linkedin|x>
goal: <answer to Q1>
media: <answer to Q2>
audience: <answer to Q5>
hook_pattern: <name of pattern from voice rules>
status: draft
created: <ISO date>
citations_verified: true          # set by Step 6.5 — true only after every claim resolved
sources:                          # one entry per sourced factual claim
  - claim: "<short>"
    url: "<url>"
    tier: <int>
citations_waived:                 # omit if none; else list reasons for explicit waivers
  - "<claim> — <why waived>"
---
```

Body: the final approved post text, followed by the first-comment block from Step 6.5:

```
<post text, ready to paste>

----- FIRST COMMENT (sources) -----
Sources:
[1] <claim, short> — <url>
[2] ...
```

`citations_verified` MUST be `true` to save (every claim sourced, softened, or waived).
If Louis waived a claim, still set `citations_verified: true` but record it under
`citations_waived` — the gate is satisfied by a conscious decision, never by silence.

### Step 8: Output

Print:
```
Draft saved to: $SOCIAL_HOME/drafts/YYYY-MM-DD-slug-platform.md

----- POST -----
<full post text>
----- END -----

----- FIRST COMMENT (sources) -----
<the sources block — paste this as the FIRST comment under the post>
-----

Copy-paste the post to <platform>, then paste the sources as the first comment.
After publishing, run /log <platform> to capture metrics.
```

## Common failure modes

- **`voice/<platform>.md` missing**: stop, suggest `/audit <platform>` first
- **User scraps mid-iteration**: do not write a file
- **Slug collision with existing draft**: append `-2`, `-3`, etc.

## Non-goals

- Does NOT publish to any platform
- Does NOT touch `data-store.yaml` (that's `/log`)
- Does NOT modify voice rules (that's `/audit`)
