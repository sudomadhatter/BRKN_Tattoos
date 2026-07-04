# Skills Registry — Curated Agent Skills for AGY Workspaces

**Last Updated:** 2026-05-29
**Purpose:** Curated list of the best agent skills available from GitHub, organized by tier and install priority. These skills teach your AI coding agents how to use specific frameworks, tools, and patterns more effectively.

---

## What Are Skills?

Skills are modular knowledge packages that follow the `SKILL.md` standard. Each skill gives your AI agent:
- **Domain knowledge** about a specific technology
- **Best practices** and anti-patterns to avoid
- **Code templates** and examples
- **Workflows** for complex multi-step tasks

Skills use **progressive disclosure** — the agent only loads the context it needs for the current task, keeping token usage efficient.

---

## Tier 1: Official / Google-Maintained (Always Install)

These are maintained by Google teams and represent the most reliable, up-to-date knowledge:

### 🔥 Firebase Agent Skills
- **Repository:** [firebase/agent-skills](https://github.com/firebase/agent-skills)
- **What you get:** Skills for Firebase Auth, Firestore, Storage, Hosting, App Hosting, Data Connect, AI Logic
- **Install:**
  ```bash
  npx skills add firebase/agent-skills
  ```

### 💎 Gemini API Skills
- **Repository:** [google-gemini/gemini-skills](https://github.com/google-gemini/gemini-skills)
- **What you get:**
  - `gemini-api-dev` — Foundational Gemini API best practices
  - `gemini-interactions-api` — Building apps with the Interactions API
  - `gemini-live-api-dev` — Real-time bidirectional streaming apps
  - `vertex-ai-api-dev` — Development on Google Cloud Vertex AI
- **Install:**
  ```bash
  npx skills add google-gemini/gemini-skills
  ```

---

## Tier 2: Community Essentials (Install Selectively)

High-quality community repositories — install the bundles that match your project:

### 🚀 Antigravity Awesome Skills (1,300+ Skills)
- **Repository:** [sickn33/antigravity-awesome-skills](https://github.com/sickn33/antigravity-awesome-skills)
- **What you get:** Massive curated library organized in bundles:
  - **Essentials** — Core development patterns
  - **Security Engineer** — Security auditing and hardening
  - **Web Wizard** — Frontend patterns and UI/UX
  - Individual skills for k8s, Docker, Git, APIs, and more
- **Install:**
  ```bash
  # Interactive installer — choose your bundles
  npx antigravity-awesome-skills

  # Or install to specific path
  npx antigravity-awesome-skills --path .agent/skills
  ```
- **⚠️ Context Warning:** Don't install ALL 1,300+ skills at once. Pick bundles relevant to your current project.

### 🎓 Antigravity Skills (5-Level Learning)
- **Repository:** [rominirani/antigravity-skills](https://github.com/rominirani/antigravity-skills)
- **What you get:** Structured skill examples at 5 complexity levels:
  1. **Basic Router** — Simple command interception
  2. **Asset Utilization** — Using templates and assets
  3. **Learning by Example** — Few-shot patterns
  4. **Procedural Logic** — Multi-step structured workflows
  5. **The Architect** — Complex scaffolding and orchestration
- **Best for:** Learning how to BUILD your own custom skills
- **Install:** Clone and copy relevant skill folders:
  ```bash
  git clone https://github.com/rominirani/antigravity-skills.git
  ```

### ⚡ Gemini Superpowers
- **Repository:** [anthonylee991/gemini-superpowers-antigravity](https://github.com/anthonylee991/gemini-superpowers-antigravity)
- **What you get:** Structured "Superpowers" workflow framework:
  - Brainstorm → Plan → Build → Review cycle
  - Structural guardrails for consistent agent behavior
- **Install:** Clone and copy workflows:
  ```bash
  git clone https://github.com/anthonylee991/gemini-superpowers-antigravity.git
  ```

### 🧠 Google GenAI SDK Skills
- **Repository:** [cnemri/google-genai-skills](https://github.com/cnemri/google-genai-skills)
- **What you get:** Skills for Google's GenAI ecosystem:
  - SDK patterns for `google-genai` Python SDK
  - Model usage best practices
  - API integration patterns
- **Install:**
  ```bash
  npx skills add cnemri/google-genai-skills
  ```

---

## Tier 3: Built-In (Already in BMAD Workspace)

These are already installed in every Clean BMAD Workspace:

### 📋 BMAD Core Skills (40+ Skills)
Full project lifecycle coverage:
- PRD creation, architecture design, story writing
- Sprint management, QA, retrospectives
- Quick-spec, quick-dev workflows
- Brainstorming, elicitation, editorial review

### 🧪 BMAD TEA Module (Test Architecture Enterprise)
- Test design and planning
- ATDD (Acceptance Test-Driven Development)
- CI pipeline scaffolding
- NFR (Non-Functional Requirements) assessment
- Requirements-to-tests traceability

### 🎨 UI/UX Pro Max
- Premium UI/UX design patterns
- Glassmorphism, micro-animations, accessibility
- Design system principles

### 🐍 Python Patterns
- Python best practices and idioms
- Async/await patterns
- Error handling strategies

### ⚛️ React Best Practices
- Component composition patterns
- Hook best practices
- Performance optimization

### 🔥 Firebase Skills
- Firebase basics, Auth, Firestore, Hosting, Storage
- Security rules patterns

### 🐛 Systematic Debugging
- Structured debugging methodology
- Root cause analysis patterns

### 🗣️ Voice AI Development (`3_voice-ai-development`)
- Audio handling (PCM16, Web Audio API, WebRTC)
- Low-latency real-time voice streaming pipelines
- Integration with Gemini Live API, OpenAI Realtime, Vapi, Deepgram, and ElevenLabs

### 📡 Server-Sent Events (SSE) Patterns (`4_sse-streaming-patterns`)
- Bidirectional communication design and SSE contract enforcement
- Handling streaming tokens, event buffering, and cleanup
- Keep-alive strategies, reconnect handling, and connection management

### 💎 Google ADK Agent Skills (`5_adk_skills`)
- Google Agent Development Kit (ADK) architecture and prompting guidelines
- Visual containment patterns (parent/sub-agent segregation)
- Prompt TDD (Test-Driven Development) frameworks and unit testing

### ☁️ GCP Cloud Run Deployment (`gcp-cloud-run`)
- Containerizing FastAPI and Next.js applications
- Scaling parameters, environment variables, and Cloud Run service config
- Secrets management, continuous delivery integration, and CORS configuration

### 🛠️ Troubleshoot Cloud Run Deployment (`troubleshoot-cloudrun-deployment`)
- Real-time logging queries and build log audits
- Health check troubleshooting and connection error recovery
- Diagnosing cold start delays and dependency errors

---

## Recommended Install Order for New Projects

```bash
# Step 1: Official Google skills (always install first)
npx skills add firebase/agent-skills
npx skills add google-gemini/gemini-skills

# Step 2: Google GenAI SDK patterns
npx skills add cnemri/google-genai-skills

# Step 3: Community bundles (selective — pick what you need)
npx antigravity-awesome-skills --path .agent/skills
```

---

## Skill File Location

Skills are installed to two possible locations:

| Scope | Path | When to Use |
|-------|------|------------|
| **Workspace** | `.agent/skills/` | Project-specific skills |
| **Global** | `~/.gemini/antigravity/skills/` | Skills available in ALL projects |

---

## Creating Custom Skills

Every skill follows this structure:
```
.agent/skills/my-custom-skill/
└── SKILL.md              # Required — instructions, examples, constraints
    scripts/              # Optional — helper scripts the LLM can't do
    examples/             # Optional — reference implementations
    resources/            # Optional — templates, assets
```

The `SKILL.md` file uses YAML frontmatter:
```yaml
---
name: My Custom Skill
description: What this skill does
---
# Instructions
[Detailed agent instructions here]
```

For advanced skill development patterns, study the [rominirani/antigravity-skills](https://github.com/rominirani/antigravity-skills) 5-level progression.
