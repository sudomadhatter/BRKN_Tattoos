# BRKN_Tattoos — workspace map  (Layer 2)

## 1. ROOT LAW (prime mission)
The **BRKN_Tattoos app** — based on the AGY quick-start project skeleton. It ships the
**default AGY stack** (FastAPI + Google ADK backend · Next.js + React + TypeScript frontend · Firebase) and the
BMAD method, **organized and indexed exactly like the home base** (`Sudo_Hatter_Command`): least-context
routing, a hybrid `docs/repo-map.md` index, `_artifacts/` memory, the 9-section contract. Clone → rename →
fill the placeholders → build. **Keep it generic — it carries the *stack*, not a *product*. No domain specifics.**

## 2. START HERE
You're inside this workspace. **Don't read the whole tree** — use the routing table (§6) to load only what
the task needs. If what you need isn't here, **GO BACK** to the home-base root `../../router.md` (or
`../../AGENTS.md`). Before any risky/irreversible action → see §8 GATES.
**Entering any folder: if it carries an `AGENTS.md`, read that FIRST** (the local law — how to act there);
read its `INDEX.md`/`README.md` only when you need the inventory. Tier model (which folders get one) →
`docs/workspace-standard.md` Part 1.

## 3. MAP / MISSION / SUPPORT
- **MAP:** Key folders —
  - `backend/` (FastAPI + ADK agents) + `frontend/` (Next.js/React/TS) — the **AGY stack scaffold** (empty
    skeleton; fill per project). Stack defaults + versions live in `docs/tech-stack.md`.
  - `_bmad/` (the BMAD module: stories + agents — **BMAD-owned, regenerated on update, never hand-edit**).
  - `_bmad-output/` (project-context, active-context, component specs, planning + `sprint-status.yaml` —
    BMAD's source of truth for state).
  - `docs/` (the **verified reference shelf**: `repo-map.md` navigation index, `workspace-standard.md`,
    `tech-stack.md`, `skills-registry.md`).
  - `scripts/` (the `/autopilot` engine · `generate_repo_map.py` index generator · `check-repo-map-drift.ps1`,
    the SessionStart drift check — see §6).
  - `_my_resources/` — **Daniel's personal area. Protected: do NOT edit or reference unless he says so (§8).**
- **MISSION:** take a BMAD story `ready-for-dev → in-progress → review → done` via plan-first dev, with
  artifacts every session.
- **SUPPORT:** the shared toolkit is vendored at `.agents/` — rules · skills · commands · workflows · the
  BMAD install. Load only what the routing table calls for (least-context).

## 4. ALWAYS-LOAD (small)
- `.agents/rules/constitution.md` (hard stops) + `.agents/rules/karpathy-guidelines.md` (how to work) +
  `.agents/rules/artifacts-always-first.md` (the plan-first gate — see §5).

## 5. ARTIFACTS PROTOCOL — MANDATORY FIRST ACTION
Before modifying ANY file outside `_artifacts/`, create `_artifacts/<YYYY-MM-DD>_<slug>/` (**project-local** —
this skeleton owns its history), start the live **TodoWrite** list, write `implementation_plan.md`, present it
inline, and **STOP until Daniel says "approved."** Close with ONE `walkthrough.md` ending in
`## Task Checklist` (final TodoWrite snapshot) + `## Your Actions` (manual steps + the exact git command) —
**no separate `task-list.md`**; add `code-review.md` /
`self-audit-stress-test.md` whenever those run. Skip only for read-only/investigatory asks and trivial
one-liners. Full protocol → `.agents/rules/artifacts-always-first.md`.

## 6. ROUTING TABLE  (task → read these / skip these / skills)
| Task | Read these | Skip these | Skills |
|---|---|---|---|
| Session boot / "what's the state?" | `docs/repo-map.md`, `_bmad-output/active-context/active-context.md`, `_bmad-output/project-context.md` | source code until you know the area | `/boot-sprint-context` |
| Workspace structure / "how do I work here?" | `docs/file_structure_rules/README.md` (this project's layout, rules & artifact workflow) | source code | — |
| Implement a story | the story in `_bmad/bmm/stories/`, the matching `_bmad-output/component-specs/*`, `active-context.md` | unrelated components | `bmad-dev-story`, `bmad-agent-dev` |
| Plan / PRD / architecture | `_bmad-output/planning-artifacts/*` | code | `bmad-agent-pm`, `bmad-create-prd`, `bmad-create-architecture` |
| Review code | the diff + the story file | — | `bmad-code-review` (+ rule `.agents/rules/bmad_code_review_fast_path.md`) |
| Autonomous dev/QA on one story | `.agents/workflows/autopilot_bmad_dev_loop.md` | — | `/autopilot <story>` (Claude engine; harness-independent) |
| Backend ADK agent architecture | `.agents/rules/adk_file_formating.md` | frontend | — |
| Voice agent work | `.agents/rules/voice-agent-architecture.md` | — | — |
| Frontend engineering & architecture | `.agents/rules/frontend-architecture.md` | backend | `react-best-practices`, `ui-ux-pro-max` |
| Frontend hook / state work | `.agents/rules/useEffect-dep-array-stability.md` | backend | `react-best-practices` |
| Re-index / repo-map drift nag | `docs/repo-map.md` | code | run `python scripts/generate_repo_map.py --ignore _bmad` (rebuild) or `scripts/check-repo-map-drift.ps1` (detect-only) |
| **"What's next" / open tasks / what's left** (Daniel's notes) | `_my_resources/open_tasks/` — `todo_list.md` + plan/PRP notes · **READ-ONLY** (never edit; cross-check vs live project files) | — | — |

## 7. NAMING CONVENTIONS (replaces a database)
Dated output `YYYY-MM-DD_<slug>.md`; versioned drafts `<slug>_v2.md` / `_final.md`. Artifacts live
**project-local** at `_artifacts/<YYYY-MM-DD>_<slug>/` (stories → `_artifacts/<epic>/<story>/`); retired history
in `_artifacts/_archived/`. See `_artifacts/INDEX.md`. Full work-from-cwd model (project-local from inside;
home-base bucket from the lobby) → root `../../AGENTS.md` §5.

## 8. GATES (consult before acting)
- **GIT WRITE APPROVAL — free on your OWN branch; the button on the owner's.**
  - **FREE:** push freely to your own `claude/*` session branch (loops/retries fine); open/update PRs.
  - **APPROVAL (per-action, never carries forward):** any write to the owner's `main` branch — a direct
    `git push` to `main`, or merging a PR into it. Merge via `/merge_main`; invoking it IS the per-action
    approval. `main` is this repo's single production/owner branch — never auto-target it for a direct push.
  - **Enforcement:** a PreToolUse hook (`.claude/hooks/require-push-approval.py`) forces the prompt on any
    `git push` targeting `main` however it's wrapped (loops, `&&`, subshells); `merge_pull_request` (plus
    `push_files`/`create_or_update_file`/`delete_file`) is gated in `.claude/settings.json`. Pushes to
    `claude/*` and PR create/update are NOT gated. Canonical detail → `.agents/rules/git-policy.md`.
- **`_my_resources/` (Daniel's personal area):** do NOT edit any file in it unless Daniel explicitly says so,
  and do NOT reference its contents unless Daniel links the specific document. Treat everything in it as
  personal brainstorming that may be stale. See `_my_resources/README.md`.
- **ROUTING + RISK:** confirm the target before touching files; never delete/overwrite/publish without an
  explicit go-ahead. Full hard stops → `.agents/rules/constitution.md`.

## 9. PERSISTENCE
- "pick up" / "hand off" → **project-local** `_artifacts/` (dated session folders + `<epic>/<story>/` +
  `_archived/`). This skeleton keeps its own history so it travels with the repo. Sessions run *from the home
  base* instead land in `../../_artifacts/BRKN_Tattoos/` — check **both** to reconstruct full history.
- The live "pick up / hand off" brief is BMAD's `_bmad-output/active-context/active-context.md` (the source of
  truth), not `_artifacts/`; `_artifacts/` holds session *history*. Append a row to `_artifacts/INDEX.md` at close.
- **"pick up" also surfaces open tasks:** after the `active-context.md` brief, read `_my_resources/open_tasks/todo_list.md`
  (+ any plan/PRP `.md` notes alongside it) and add a one-line "what's queued." **READ-ONLY** — Daniel's notes;
  never edit; cross-check vs live files. (Same source the §6 "What's next" routing row uses.)
