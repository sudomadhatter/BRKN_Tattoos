---
trigger: model_decision
description: "Activates when modifying any prompts.py file in backend/agents/. Enforces structural TDD for prompt construction — every prompt change gets tests that verify the instructions reach the model correctly."
---

# Prompt TDD Rules

> Source: Extracted from Epic 5 Retrospective (2026-05-20). Pattern proven across 81 tests in Stories 5.2, 5.3, 5.5, 5.6, 5.7, 5.8.

## 1. Every Prompt Modification Gets Structural Tests

When modifying `prompts.py`, you MUST write or update tests that verify the **structure** of the generated prompt:
- Text presence: expected strings appear in the output
- Text absence: conditional sections are NOT present when their gate is false
- Ordering: sections appear in the correct sequence
- Conditional injection: sections appear/disappear based on input data (e.g., `len(filtered) >= 2`)

## 2. Test What You Control, Not What the Model Does

Prompt structure tests verify that the *instructions* are correct — NOT that the model will follow them. The model's behavior is verified through manual testing.

| ✅ Test This | ❌ Don't Test This |
|---|---|
| "RADIOACTIVE" appears in prompt text | Whether Gemini actually avoids saying the answer |
| Rule 5 injected when 2+ RKPs present | Whether Sully actually skips a redundant RKP |
| ConsequenceTracker prompt matches depth-3 | Whether the model degrades aircraft state correctly |

## 3. Test File Naming Convention

| Pattern | Convention |
|---|---|
| General prompt tests | `backend/tests/agents/test_{agent}_prompts.py` |
| Feature-specific tests | `backend/tests/agents/test_{agent}_{feature}.py` |

Examples:
- `test_sully_prompts.py` — core prompt construction
- `test_sully_rkp_section_awareness.py` — Story 5.8 specific
- `test_sully_pause_telemetry.py` — Story 5.2 specific
- `test_sully_consequence_engine.py` — Story 5.3 specific

## 4. Use MagicMock Fixtures for External Data

Prompt builder functions take structured data (RKP manifests, mastery state, student context). Use `unittest.mock.MagicMock` to create fixtures — don't depend on Firestore or file system.

```python
# Example pattern from test_sully_prompts.py
@pytest.fixture
def mock_rkp_manifest():
    manifest = MagicMock()
    manifest.lesson_title = "Weather Theory"
    manifest.required_knowledge_points = [mock_rkp_1, mock_rkp_2]
    return manifest
```

## 5. Regression Suite Is Non-Negotiable

After adding a new prompt feature, run the FULL existing test suite for that agent's prompts. A new rule must not break existing rules.

```bash
pytest backend/tests/agents/test_sully_prompts.py -v
pytest backend/tests/agents/test_sully_*.py -v  # all feature tests
```
