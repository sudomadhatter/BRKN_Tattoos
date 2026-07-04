# 🚀 AGY Quick-Start Project Skeleton (clean-bmad)

A **ready-to-build project skeleton** that ships the default AGY tech stack and is organized, indexed, and
governed exactly like the `Sudo_Hatter_Command` home base. Clone it to start a new project and skip months of
setup — the routing brain, the toolkit, the BMAD method, and the self-indexing repo-map are already wired.

> **Keep it generic.** This carries the **stack**, not a **product**. Don't bake domain specifics into the
> skeleton itself — fill them in *after* you clone.

---

## ⚡ Quick Start — new project in ~10 minutes

### 1. Clone the skeleton
```bash
git clone <this-skeleton-repo> your-new-project-AGY
cd your-new-project-AGY
Remove-Item -Recurse -Force .git    # drop the template's history (PowerShell)
git init
```

### 2. Find & replace the placeholders
Search the repo for `{{...}}` tokens and replace them with your project's values:

| Placeholder | Replace with | Where it lives |
|---|---|---|
| `{{PROJECT_NAME}}` | Your project name (e.g. `MyApp`) | `_bmad-output/project-context.md`, `.antigravity/mcp.json`, `.env.example` |
| `{{PROJECT_DESCRIPTION}}` | One-line description | `_bmad-output/project-context.md` |
| `{{TECH_STACK_FRONTEND/BACKEND/DB}}` | Your stack choices (defaults in `docs/tech-stack.md`) | `_bmad-output/project-context.md` |
| `{{ARCHITECTURE_PATTERN_DESCRIPTION}}` | Your architecture in one line | `_bmad-output/project-context.md` |

Then re-point the workspace's own references to the new name:
- `AGENTS.md` §9 + `.claude/settings.json` (the SessionStart hook path) — swap `clean-bmad-workspace` for your
  project's folder name so memory/continuity resolves to `../../_artifacts/<your-project>/` at the home base.

### 3. Set up the backend (FastAPI + ADK)
```bash
python -m venv .venv
.venv\Scripts\activate
pip install -r backend/requirements.txt    # stack template in docs/tech-stack.md
```

### 4. Set up the frontend (Next.js / React / TS)
```bash
cd frontend
npx create-next-app@latest ./ --typescript --tailwind --eslint --app --src-dir
npm install                                 # deps template in docs/tech-stack.md
```

### 5. Point the type checker at your venv
Update the interpreter/search paths in `pyrefly.toml` + `pyrightconfig.json` to your new project path.

### 6. Configure environment + Firebase
```bash
mkdir auth_keys
copy .env.example auth_keys\.env            # then edit with your real keys
```

### 7. Build with BMAD
```
/bmad-product-brief        # start with a brief
/bmad-prd                  # then the PRD
/bmad-create-architecture  # design it
/bmad-create-epics-and-stories
/bmad-dev-story            # implement
```

---

## 📁 Directory structure

```text
your-project/
├── AGENTS.md              # THE BRAIN — 9-section workspace map + routing table (read first)
├── CLAUDE.md / GEMINI.md  # one-line adapters → "read AGENTS.md"
├── opencode.json          # least-context instructions + .agents/skills path
│
├── .agents/               # vendored master toolkit (rules · skills · commands · workflows · bmad · scripts · templates)
├── .claude/ .opencode/    # synced tool dirs (resolve /commands + skills) — incl. the SessionStart hook
├── .antigravity/mcp.json  # MCP servers (Firebase, …)
│
├── docs/                  # the verified reference shelf
│   ├── repo-map.md        #   ← the hybrid INDEX (curated header + auto-generated tree); self-checks on session start
│   ├── workspace-standard.md   # how this (and every) workspace is shaped + kept healthy
│   ├── tech-stack.md      #   the AGY default stack + versions
│   └── skills-registry.md #   curated agent skills + install guide
│
├── scripts/               # generate_repo_map.py (rebuild index) · check-repo-map-drift.ps1 (drift nag) · autopilot engine
│
├── _bmad/                 # BMAD method module (BMAD-owned — never hand-edit)
├── _bmad-output/          # BMAD state: project-context · active-context · component-specs · planning/test artifacts
├── _artifacts/            # project-local agent memory — plans/walkthroughs/handoffs · INDEX.md · <epic>/<story>/ · _archived/
│
├── backend/               # FastAPI + ADK scaffold (agents/ routers/ schemas/ services/ tools/ tests/)
├── frontend/              # Next.js / React / TS scaffold
│
├── _my_resources/         # ⚠️ Daniel's PERSONAL area — do NOT edit or reference unless he links the doc
├── firebase.json · firestore.* · storage.rules     # Firebase config
├── pyproject.toml · conftest.py · pyrefly.toml · pyrightconfig.json   # Python tooling
└── .env.example · .gitignore · .gitattributes
```

> **Session memory is project-local.** Plans, walkthroughs, and continuity write to this repo's own
> `_artifacts/` (dated `<YYYY-MM-DD>_<slug>/` folders · `<epic>/<story>/` · `_archived/`), so the history
> travels with the repo — same model as every other project. (Sessions run *from the home base* instead land in
> `../../_artifacts/clean-bmad-workspace/`; check both to reconstruct full history.) The live pick-up/hand-off
> brief is BMAD's `_bmad-output/active-context/active-context.md`. Full rule → `docs/file_structure_rules/README.md`.

---

## 🧭 How the Folder & File Structure Works

This project uses a **folder-as-workspace** organization method. The folder structure _is_ the application —
markdown files are the program, and AI agents become whatever the workspace describes. There is no framework,
no database, and no hidden state. Everything is plain-text, portable, and version-controlled.

### The core idea: least-context loading

An AI agent should never read the whole repo tree. Instead, it reads **only what the current task needs**,
routed there by plain-English tables in `AGENTS.md`. This keeps context windows small, responses fast, and
hallucination low.

### Three layers make it work

| Layer | What it is | Files |
|---|---|---|
| **1 — Entry + Map** | One-line adapters route any LLM to the brain | `CLAUDE.md`, `GEMINI.md` → `AGENTS.md` (9-section workspace map) |
| **2 — Routing Table** | The heart — a plain-English table: *task → read these / skip these / skills* | §6 inside `AGENTS.md` |
| **3 — Skills** | Specialized instructions loaded on demand, never globally | `.agents/skills/<name>/SKILL.md` |

### Key directories and what they do

| Directory | Role | Rule |
|---|---|---|
| `.agents/` | **Vendored toolkit** — rules, skills, commands, workflows, scripts, templates | Single source of authorship lives at the home base; copies here are synced via `/sync-agents`. Never hand-edit a vendored copy. |
| `docs/` | **Verified reference shelf** — repo-map, workspace standard, tech stack, skills registry | The repo-map auto-checks for drift on session start; the standard is the standing spec. |
| `_artifacts/` | **Session memory** — plans, walkthroughs, handoffs, and the `INDEX.md` ledger | Project-local: dated `<YYYY-MM-DD>_<slug>/` folders for tasks, `<epic>/<story>/` for stories, `_archived/` for retired history. |
| `_bmad/` | **BMAD method module** — the Agile framework's agents, stories, and configuration | BMAD-owned and regenerated on update. **Never hand-edit.** |
| `_bmad-output/` | **BMAD state** — project-context, active-context (the live continuity brief), component specs, planning artifacts | The source of truth for project state and agent pickup/handoff. |
| `_my_resources/` | **Daniel's personal area** — brainstorming, notes, open tasks | Protected. Agents read `open_tasks/` (READ-ONLY) but never edit anything here. |
| `backend/` / `frontend/` | **The code** — FastAPI + ADK scaffold / Next.js + React + TS scaffold | Fill per project; stack defaults in `docs/tech-stack.md`. |

### How agents remember across sessions

Every non-trivial task follows **plan-first discipline**:

1. **Research** (read-only) → write an `implementation_plan.md` → **STOP for approval**
2. **Execute** with a live task checklist
3. **Close** with a `walkthrough.md` (what changed + test output + exact git commands for the user)
4. **Persist** — append a row to `_artifacts/INDEX.md`, update `_bmad-output/active-context/active-context.md`

This means any agent (Claude, Gemini, opencode) can "pick up" where the last one left off by reading
`active-context.md` — no chat history required. The full workspace standard is at
[docs/workspace-standard.md](docs/workspace-standard.md).

### Model-agnostic by design

`AGENTS.md` is the universal contract. `CLAUDE.md` and `GEMINI.md` are one-line adapters that say
"read `AGENTS.md`." Nothing model-specific lives in shared files — so Claude, opencode, and
Antigravity/Gemini all drive the same system, and your work is saved to **your** files, not a vendor's
memory.

---

## 🎯 How BMAD Works — Agentic Agile Development

**BMAD** (BMad Method) is a full-lifecycle Agile framework designed for AI-assisted development. It gives
AI agents the same structured workflow a human Agile team would follow — from product discovery through
sprint delivery — but adapted for agent capabilities.

### The lifecycle: idea → shipped code

```
Product Brief → PRD → Architecture → Epics & Stories → Sprint Plan → Story Dev → Code Review → Retro
```

Each phase has a dedicated **BMAD skill** (a specialized instruction set) and optionally a named **agent
persona** that the AI becomes when you invoke it:

| Phase | Skill / Command | Agent Persona | What it produces |
|---|---|---|---|
| **Discovery** | `/bmad-product-brief` | — | A validated product brief |
| **Requirements** | `/bmad-prd` | John (PM) | A complete PRD with user stories and acceptance criteria |
| **Architecture** | `/bmad-create-architecture` | Winston (Architect) | Solution design, tech decisions, component specs |
| **Planning** | `/bmad-create-epics-and-stories` | — | Epics broken into implementable stories |
| **Sprint** | `/bmad-sprint-planning` | — | Sprint plan with story priorities and status tracking |
| **Implementation** | `/bmad-dev-story` | Amelia (Dev) | Working code from a story spec, following plan-first discipline |
| **Review** | `/bmad-code-review` | — | Multi-layer adversarial code review (blind hunter + edge case + acceptance audit) |
| **QA / Testing** | `/bmad-tea` | Murat (Test Architect) | Test strategy, ATDD scaffolds, traceability |
| **Retrospective** | `/bmad-retrospective` | — | Post-epic lessons learned |

### What lives where

- **`_bmad/`** — The method itself. Contains the agent definitions, story templates, and core workflow
  logic. This is BMAD-owned and regenerated on updates — **never hand-edit these files.**
- **`_bmad-output/`** — The project's BMAD state. This is where the work products live:
  - `project-context.md` — The project identity (name, stack, architecture pattern)
  - `active-context/active-context.md` — The **live continuity brief** (what's happening now, what to
    pick up next)
  - Component specs, planning artifacts, and `sprint-status.yaml`

### Using BMAD day-to-day

**Starting a new project from this skeleton:**
```
/bmad-product-brief        # "What are we building and why?"
/bmad-prd                  # "What exactly does it need to do?"
/bmad-create-architecture  # "How will we build it?"
/bmad-create-epics-and-stories  # "Break it into deliverable chunks"
/bmad-sprint-planning      # "What's the order of work?"
```

**Implementing a story:**
```
/bmad-dev-story <story-file>   # Agent reads the story spec, writes plan, codes, tests
```

**Checking progress:**
```
/bmad-sprint-status        # Where are we in the sprint?
/bmad-code-review          # Adversarial review of recent changes
```

> **The key insight:** BMAD doesn't replace human judgment — it structures AI work so that every agent
> session produces traceable artifacts (plans, code, reviews, walkthroughs) instead of ephemeral chat.
> The human approves plans before execution and merges code after review. The AI does the heavy lifting
> within those guardrails.

---

## 🔧 What's Pre-Configured

- **The routing brain** — `AGENTS.md` is a 9-section workspace map with a plain-English routing table
  (*task → read these / skip these / skills*). Least-context loading by default; it routes you UP to the home
  base when a need isn't covered here.
- **The vendored toolkit** (`.agents/`) — rules, the full BMAD skill suite, commands, and workflows. Edit at the
  master and re-sync; never hand-edit the vendored copies.
- **The hybrid auto-updating repo-map** — `docs/repo-map.md` has a hand-written curated header + an
  auto-generated folder/signature tree. The `.claude/settings.json` **SessionStart hook injects it and runs a
  detect-only drift check** — it nags when a folder appears on disk but not in the map. Rebuild the tree with
  `python scripts/generate_repo_map.py --ignore _bmad`.
- **BMAD method** (`_bmad/` + `_bmad-output/`) — full Agentic Agile lifecycle, from product brief through retrospective.
- **The AGY stack** — FastAPI + Google ADK backend · Next.js + React + TypeScript frontend · Firebase, with the
  configs and version templates ready (`docs/tech-stack.md`).

---

## 📚 Key Documentation

| Document | Read it when |
|---|---|
| [AGENTS.md](AGENTS.md) | Always first — the workspace brain + routing table |
| [docs/repo-map.md](docs/repo-map.md) | "Where is X / what's the shape of this repo?" |
| [docs/workspace-standard.md](docs/workspace-standard.md) | Formatting or upkeeping this (or any) workspace |
| [docs/tech-stack.md](docs/tech-stack.md) | Need the stack / versions |
| [docs/skills-registry.md](docs/skills-registry.md) | Looking for an available skill |

---

## 🍎 Our Standard

> If it doesn't feel like it came from Apple's design lab and function with the reliability of an aircraft
> system — **it's not finished.**
