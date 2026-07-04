"""
Root-level conftest for pytest.

Ensures 'backend' is importable as a top-level package by
inserting the project root into sys.path before collection.
"""
import sys
from pathlib import Path

# Add project root so `import backend.*` resolves correctly
_project_root = str(Path(__file__).resolve().parent)
if _project_root not in sys.path:
    sys.path.insert(0, _project_root)
