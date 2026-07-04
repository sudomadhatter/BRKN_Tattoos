---
description: Activates when executing scripts, running tests, or initializing backend services that require Firebase credentials.
---
# Environment and Credential Resolution

When executing python scripts, tests, or background tasks, NEVER hardcode relative paths to `auth_keys/service-account.json`. 

Agents frequently execute commands from nested subdirectories (like `cd backend && python -m pytest`), which causes relative pathing to fail.

### The Standard Pattern

The AviationChat repository uses a dynamically resolved absolute path pattern to ensure credentials are found regardless of the current working directory. On all computers checking out this repo, the credentials live at the root `auth_keys/` folder or are defined via `.env`.

**When writing new scripts that need Firebase or Google Auth, use this pattern:**

```python
import os

# 1. Check if the environment already specifies a key path (useful for different developer machines)
cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS")

if not cred_path:
    # 2. Dynamically resolve to the root directory's auth_keys folder
    # Assuming the current file is inside a module like `backend/main.py`:
    cred_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "auth_keys", "service-account.json")

# 3. Export back to the environment so secondary libraries (like Google Cloud Firestore clients) 
# can automatically discover the credentials during runtime or test execution.
if cred_path and os.path.exists(cred_path):
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = cred_path
else:
    print(f"WARNING: No credentials found at {cred_path}")
```

### Why this is important for multi-machine setups
The `.gitignore` strictly ignores the `auth_keys/` folder. This means developers cloning the repo on other computers must either:
1. Re-create the `auth_keys/service-account.json` directory at the project root.
2. Supply their own location by setting `GOOGLE_APPLICATION_CREDENTIALS` in their local `.env` file.

The resolution logic above seamlessly supports both workflows without breaking tests.
