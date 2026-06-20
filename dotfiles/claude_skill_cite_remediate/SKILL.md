---
user-invocable: true
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Agent, WebSearch, WebFetch, AskUserQuestion
description: Phase 2 of /cite — subagents find sources (raw data only); the orchestrator finalizes tier/recency/status, auto-promote, and corroboration deterministically via scripts. Stops at a review gate.
---

# /cite-remediate — Source Hunting, Auto-Promote, Corroboration

## Trigger
`/cite-remediate [<slug>]`  (no slug → AskUserQuestion lists `~/.local/state/cite/*/` and legacy `docs/citation-audit/*/`)

Set `S=~/.claude/skills/cite/scripts`. Resolve `BUNDLE` for the slug.

## Which claims get worked
- **Source-hunt** (uncited, cited-broken, cited-stale, cited-low-tier).
- **Leave alone** cited-healthy (cost control).
- **Active corroboration hunt** only where it changes a decision: best source tier∈{5,6,null}, forecasts, and auto-promote candidates.

## Step 1: Load state
Read `outline.md`, `meta.yaml` (for project-overlay path + converted_md), and all claim YAMLs needing work.

## Step 2: Dispatch parallel research subagents (batches of 5, `subagent_type: general-purpose`)
Each subagent gets ONE claim and returns **raw data only** — never tier/recency/status/promote. Reuse the anti-fabrication contract from the legacy cite-research prompt verbatim (quote + surrounding_paragraph MUST appear in the saved `claims/<id>.page.txt`; fallback chain Tavily extract → WebFetch → curl+pdftotext; on retry honor `--error-feedback`). Tooling note in the prompt: use `python3 ~/.claude/skills/cite/scripts/tavily_cli.py search "<q>" --domain <d> --days <n>` then `... extract <url>` (falls back to WebFetch).

ADD to the returned fields:
```yaml
proposed_source: { ... same as legacy ... , underlying_origin: <stated study/dataset/org or null> }
corroboration:
  sources:                       # EVERY extra candidate seen — never discard
    - {url, url_domain, publication_date, snippet, underlying_origin, page_text_file: <id>.corrob-K.page.txt or null}
```
Instruct the subagent: if a second source is cheaply available (already in search results), save its page text too as `<id>.corrob-K.page.txt` so the orchestrator can validate it.

## Step 3: Deterministic finalization (orchestrator, per returned claim)
1. **Validate primary**: `python3 $S/validate_claim.py "$BUNDLE/claims/<id>.yaml" "$BUNDLE/claims/<id>.page.txt"`. Exit 1 → retry once with stderr as `--error-feedback`; second failure → `status: flagged-validation-failed`, log to caveats, skip rest.
2. **Tier**: `python3 $S/tier_lookup.py <url_domain> --map ~/.claude/skills/cite/memory/authority-map.yaml [--map <project-overlay> --map "$BUNDLE/authority-map.yaml"]` → `proposed_source.authority_tier`.
3. **Recency**: `python3 $S/decisions.py recency "<publication_date or ''>"` → `proposed_source.recency_verdict`.
4. **Base status**: `python3 $S/decisions.py status <tier|null> <recency>` → status + flag_reason.
5. **Corroboration** (for each saved `corrob-K.page.txt`):
   - validate it the same way (quote findable) → `validated`.
   - independence: `python3 $S/textsim.py "$BUNDLE/claims/<id>.page.txt" "$BUNDLE/claims/<id>.corrob-K.page.txt"` → if `near_duplicate` true → not independent. Also require `underlying_origin` distinct & stated from the primary's. Set `independent: true/false/null`.
   - value: `python3 $S/value_match.py "<claim text>" "<corrob quote>"` → `value_match: true/false`.
   - Set `corroboration.status` per `decisions.corroboration_status` (compute in-orchestrator using the table, or call the module). Then `status = decisions.apply_corroboration(status, tier, secondaries)` — a low-tier claim with an independent validated tier≤4 secondary becomes auto-approved.
6. **Auto-promote** (only for claims that had `existing_source`):
   - `VM=$(python3 $S/value_match.py "<claim text>" "<new quote>")` (match/mismatch/unknown)
   - `python3 $S/decisions.py promote <orig_tier|null> "<orig_date or ''>" <new_tier|null> "<new_date or ''>" <VM> <determinable>` → `promote_verdict`.
   - `auto-promote` → `status: auto-promoted`, `proposed_action: swap-source`.
   - `flag-claim-conflict` → `status: flagged-claim-conflict` (record `proposed_claim_update` with the new value + source for human review).
   - `flag-better-source` → `status: flagged-better-source`.
7. Write the `validation:` block (validated_at, quote_found_in_page, attempts).

## Step 4: Update outline.md
Sections: Auto-approved (incl. auto-promoted, corroboration-upgraded) · Flagged-review (low-rep / claim-conflict / better-source / validation-failed) · Unsourceable. Show corroboration status per claim.

## Step 5: Report + gate
```
/cite-remediate complete for <slug>
- <a> auto-approved (<p> via auto-promote, <c> via corroboration)
- <f> flagged · <u> unsourceable · <conf> conflicts
Edit flagged claims' YAML status to approved|rejected|needs-rework, then run /cite-correct.
```

## Common failure modes
- No `.scan-hash` → "run /cite-diagnose first".
- Tavily rate limit → WebSearch fallback, log each to caveats.
- Subagent error → retry once, else flagged-unsourceable.

## Non-goals (v1)
- Does NOT edit the document. Does NOT re-research needs-rework in the same run. Never auto-changes a claim's value.
