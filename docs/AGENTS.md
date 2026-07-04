# `docs/` — LOCAL LAW (verified reference shelf)

This skeleton's **verified reference shelf** — confirmed-current docs only. Load per task — nothing
here is a startup payload except `repo-map.md` (injected/drift-checked at SessionStart).

## The law
- `repo-map.md` — hybrid navigation index. **CURATED header: hand-edited. AUTO body (between the
  sentinels): machine-owned** — regenerate per the header's documented command
  (`python scripts/generate_repo_map.py --ignore _bmad`), never hand-edit inside the sentinels.
- `workspace-standard.md` — **vendored copy** of the structure contract; the canon lives in the home
  base's `docs/`. **`docs/` is NOT covered by `/sync-agents`** — never hand-edit the vendored copy; it is
  refreshed from canon in a deliberate per-project pass.
- `.maps-state.json` — machine-managed drift anchor (`check_maps.py --set-anchor`, run AFTER committing).
  Never hand-edit.
- `tech-stack.md` (stack defaults + versions) · `skills-registry.md` (available skills) ·
  `file_structure_rules/` (this workspace's layout / how-to-work-here guide).
- Docs get here by **promotion** (Daniel verifies them current) — don't dump drafts here; drafts live in
  `_artifacts/` session folders (or `_my_resources/`, which is his).
- Added/removed a file here → the repo-map AUTO body drifts; run `/1_update-maps` (or the generator)
  before hand-off.
