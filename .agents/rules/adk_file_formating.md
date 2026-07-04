---
trigger: model_decision
description: "Activates when creating, renaming, reorganizing, or adding new agents in backend/agents/. Enforces the Visual Containment nesting pattern, component pattern, and dependency proxy rules."
---

# ADK Agent Architecture Rules (Visual Containment)

## 1. No Abstract Catigory Folders
Never create `orchestrators/`, `specialists/`, or similar grouping folders. The folder name IS the agent name.

## 2. Agent Hierarchy
- **Parent Agents**: `backend/agents/<name>/` — directly called by routers
- **Sub-Agents**: `backend/agents/<parent>/sub_agents/<name>/` — support a single parent
- Current parents: `greeting`, `hr`, `specialist`, `admin`

## 3. The Component Pattern (Mandatory)

| File | Purpose |
|---|---|
| `agent.py` | Logic, execution flow, SDK usage, tool bindings |
| `prompts.py` | Persona, system instruction string, message formatting |
| `__init__.py` | Exports the agent object — **required at EVERY directory level** (Pyrefly fails without them) |
| `evals/` | *(Optional)* ADK evaluation data |

> No instruction strings in `agent.py`. No Python logic in `prompts.py`.

## 4. Permitted Exceptions
Agent-local files allowed only for: `hr/schemas.py`, `hr/services.py`, `reasoner/schemas.py`, `greeting/tools/signup_trigger.py`. Must be verifiably not shared by any other agent.

## 5. Global Tools
Shared utilities → `backend/tools/` as pure Python. No ADK imports.

## 6. Dependency Proxy Pattern
When a sub-agent depends on a global tool, create `_<tool>_proxy.py` with only the import.

## 7. Specialist Orchestrator Exception
`specialist/agent.py` is a hand-coded Python class, NOT an `LlmAgent`. The 3-lane async architecture requires it. Do NOT refactor to `LlmAgent`.

## 8. Implementation Rules
- Use `google.adk.agents.LlmAgent` (except Rule 7)
- Use `google.adk.models.Gemini` with `api_key=os.getenv("GEMINI_API_KEY")`
- Register tools via `FunctionTool`
- Call it "Reasoner" — never "Verifier"

## 9. Model Assignment
- Complex reasoning / fact-checking → **Gemini 3.0 Pro**
- Fast streaming / acknowledgments → **Gemini 3.0 Flash**

## 10. Prompt Architecture Standard
When generating or modifying the `prompts.py` file for any agent, you MUST consult and apply the Prompt Architecture doctrine in `.agents/skills/v3-prompt-architecture/SKILL.md` (the in-repo doctrine of record).