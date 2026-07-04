---
name: pyrefly-paths
description: "Activates when editing pyrefly.toml, resolving Python import errors, or debugging 'Could not find import' type checker issues on Windows."
activation: Model Decision
---

# Pyrefly Path & Type Safety Rules

## 1. Always Use Double Backslashes in `pyrefly.toml`

On Windows, Pyrefly requires native path separators. Forward slashes cause silent config failures where `search roots` report as empty `()`.

```toml
# ✅ Correct
python-interpreter-path = "c:\\Sudo_Hatter_Command\\aviationChat-AGY\\.venv\\Scripts\\python.exe"
search_path = [
    "c:\\Sudo_Hatter_Command\\aviationChat-AGY",
    "c:\\Sudo_Hatter_Command\\aviationChat-AGY\\.venv\\Lib\\site-packages"
]
```

## 2. Pyrefly Does NOT Hot-Reload Config

After editing `pyrefly.toml`, the user **must** reload: `Ctrl+Shift+P` → `"Developer: Reload Window"`. Always remind the user.

## 3. Type Narrowing Workarounds

Pyrefly has known limitations with type narrowing after try/except and dict union types.

**Optional attribute access after try/except** — extract to a typed variable:
```python
# ✅ Extract with explicit type annotation
content: Optional[str] = ctx.lesson_content if ctx else None
async for chunk in agent.stream(lesson_content=content):
```

**Dict mutation on union types** — reconstruct instead of mutating:
```python
# ✅ Reconstruct explicitly
result = {"status": "partial", "data": result.get("data", [])}
```

## 4. "Could not find import" with Correct Config

1. Verify paths use `\\` not `/`
2. Reload IDE window
3. If still broken: `Ctrl+Shift+P` → `"Python: Clear Cache and Reload"`
4. Check for missing `__init__.py` — every directory in the import chain must have one
