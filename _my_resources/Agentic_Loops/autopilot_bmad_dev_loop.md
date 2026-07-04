# Autopilot BMAD Dev Loop — moved to the shared toolkit

The full, model-agnostic reference now lives in the shared `.agents/` toolkit as the **single source**:

→ [`.agents/workflows/autopilot_bmad_dev_loop.md`](../../.agents/workflows/autopilot_bmad_dev_loop.md)

It is authored at the home-base master `.agents/workflows/` and vendored into every project by
`/sync-agents`. **Edit the master, never this pointer or the vendored copy.**

Quick facts (see the full doc for everything):
- **Trigger:** `/autopilot_claude <story>` (or `/autopilot_opencode`) — a 4-stage Dev/QA relay (Plan → Audit → Implement → Review+Fix).
- **Engine:** `scripts/autopilot-dev-story.ps1` (project-local; resolves repo root as its own parent).
- **Harness-independent:** launch it from Claude, opencode, Antigravity, or a bare terminal — it spawns
  its own headless `claude` workers and still runs Opus 4.8. The engine is Claude by choice; the relay,
  handoff, and test gate are vendor-neutral.
- **Tuning:** prefer dialing per-role *effort* (the "think hard" prompt keyword) over downgrading the
  model — Opus-4.8-at-lower-effort beat dropping the Dev to Sonnet 4.6 (same cost, better results).
