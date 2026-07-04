---
trigger: model_decision
description: "Activates when creating stories, implementation plans, or modifying code in backend/agents/sully/ or backend/agents/igor/. Enforces the voice-first architecture that is fundamentally different from the Specialist text pipeline."
---

# Voice Agent Architecture Rules

> Source: Extracted from Epic 5 Retrospective (2026-05-20). Patterns proven across Stories 5.0–5.8.

## 1. Prompt-Only Is the Default

Voice agent stories MUST default to **prompt-only solutions** (system prompt engineering in `prompts.py`) unless there is a proven need for backend state changes. The burden of proof is on the person proposing backend changes, not the person proposing prompt engineering.

**Why:** Story 5.8 was originally specced with backend state changes ported from the Specialist pipeline. The correct implementation was 15 lines of prompt text. The Specialist uses backend state machines for flow control; Sully/Igor delegate all flow control to Gemini via prompt engineering + tool-based evaluation.

## 2. Aviation-Metaphor Register (Mandatory)

All LIVE ORCHESTRATION PROTOCOL extensions MUST use the same register as existing rules:
- **Game framing:** "WINNING" / "LOSING" (not "success" / "failure")
- **Visceral anchors:** "RADIOACTIVE" (not "forbidden" or "restricted")
- **Aviation metaphors:** "cockpit", "flight plan", "waypoints", "re-fly" (not clinical instruction text)

**Why:** Gemini Live voice models internalize goal-oriented metaphor framing. Clinical instruction text ("When the student demonstrates knowledge covering RKP N, advance to RKP N+1") gets ignored or inconsistently followed.

## 3. Extend Protocols Inline

New behavioral rules for voice agents MUST be numbered continuations within the existing LIVE ORCHESTRATION PROTOCOL (Rule 5, Rule 6, etc.). NEVER add separate XML blocks (e.g., `<section_awareness>`) — they risk logical contradictions with existing directives.

**Why:** The protocol at line 168 says "without skipping." A separate block simultaneously saying "you may skip" creates a contradiction the model resolves unpredictably.

## 4. Session-Scoped State Only

Mutable state classes (ConsequenceTracker, PauseTelemetryManager, SlidingWindow) MUST be instantiated inside the `async with session` block and consumed by a single async task (`gemini_to_browser`). No cross-task mutation. No global state.

**Why:** Single-consumer pattern is inherently thread-safe. Epic 5 had zero concurrency bugs — a direct contrast to Epic 4's stale-closure SSE epidemic.

## 5. WebSocket Override Safety

Any `send_realtime_input(text=...)` override call MUST be wrapped in `try/except`. The session may be closed by idle timeout or watchdog simultaneously. The override becoming a no-op is acceptable; an unhandled exception crashing the pipeline is not.

## 6. Do NOT Port Specialist Patterns

The following Specialist-pipeline patterns do NOT apply to voice agents:
- ❌ Backend state machines for flow control → Use prompt rules instead
- ❌ SSE event parsing → WebSocket is bidirectional
- ❌ Zustand stores → No frontend state management for voice
- ❌ Multi-agent orchestration → Single model with tool-based evaluation
- ❌ `session_context.py` state objects → Session-scoped classes inside `async with`

## 7. WebSocket Teardown Ordering (CRITICAL)

The backend MUST NOT send `session_end` before all final telemetry/debrief calculations are compiled and sent to the frontend. Sending `session_end` triggers the frontend to terminate/close the WebSocket connection immediately, which will drop any subsequent messages (like `igor_debrief`) still in flight or queued in the backend's `finally` block. 

Always ensure `session_end` is the absolute last message emitted during clean teardown.
(Source: Story 8.10, 2026-05-29)

