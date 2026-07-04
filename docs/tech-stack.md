# Preferred Tech Stack — AGY Standard

**Last Updated:** 2026-03-28
**Purpose:** This document defines our default technology choices for new projects. These are battle-tested production technologies sourced from our production systems.

---

## 🎯 Decision Philosophy

| Principle | Meaning |
|-----------|---------|
| **Google-First** | Prefer Google ecosystem tools (ADK, Gemini, Firebase, GCP) for AI/ML and infrastructure |
| **Async-Native** | Choose frameworks that support async/await natively (FastAPI, not Flask) |
| **Type-Safe** | Static typing everywhere — TypeScript on frontend, Pydantic + Pyrefly on backend |
| **Latest Stable** | Pin to latest stable versions, update quarterly |
| **Minimal Dependencies** | Fewer deps = fewer CVEs. Every dependency must earn its place. |

---

## Backend Stack

### Core Framework

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Python** | 3.13+ | Language runtime | Latest stable, performance improvements, pattern matching |
| **FastAPI** | 0.129.0+ | Web framework | Async-first, auto-generated OpenAPI docs, Pydantic integration |
| **Uvicorn** | 0.41.0+ | ASGI server | Production ASGI with `--reload` for development |
| **python-dotenv** | 1.2.1+ | Env management | Load `.env` files for local development |

### AI & Agent Framework

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Google ADK** | 1.26.0+ | Agent orchestration | Multi-agent systems, tool registration, built-in eval framework |
| **google-genai** | 1.64.0+ | Gemini AI SDK | Unified Google AI SDK (replaces legacy `google-generativeai`) |
| **gemini-3-flash-preview** | Latest | Fast AI model | Streaming, routing, conversational responses |
| **gemini-3-pro-preview** | Latest | Reasoning AI model | Complex reasoning, verification, fact-checking, grading |

> ⚠️ **NEVER** use legacy Gemini 2.x models. Always use Gemini 3.0 Flash or Pro.

### Database & Search

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Cloud Firestore** | via firebase-admin 7.1.0+ | Primary database | NoSQL, real-time sync, serverless scaling, multi-database |
| **Firebase Auth** | via firebase SDK 12.7.0+ | Authentication | Google Sign-In, session management, security rules |
| **Vertex AI Search** | discovery engine 0.13.12+ | RAG / Document search | Enterprise document search with grounding |

### Middleware & Streaming

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **sse-starlette** | 3.2.0+ | Server-Sent Events | Production SSE for real-time agent response streaming |
| **SlowAPI** | 0.1.9+ | Rate limiting | Per-endpoint rate limiting middleware |

### Backend Testing

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Pytest** | 9.0.2+ | Test runner | Industry standard, fixture system, plugins |
| **pytest-asyncio** | 0.25.0+ | Async test support | Required for testing async FastAPI endpoints and ADK agents |
| **httpx** | 0.28.1+ | HTTP test client | Async HTTP client for API testing |

---

## Frontend Stack

### Core Framework

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Next.js** | 16+ | React framework | App Router, SSR/SSG/ISR, API proxy, serverless functions |
| **React** | 19+ | UI library | Concurrent features, hooks, server components |
| **TypeScript** | 5+ | Type system | Strict mode, discriminated unions, branded types |

### Styling & Design System

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Tailwind CSS** | 3.4+ | Utility-first CSS | HSL CSS variables, dark mode via `class`, rapid prototyping |
| **Radix UI** | Latest | Accessible primitives | Unstyled, WAI-ARIA compliant, composable |
| **CVA** | Latest | Component variants | Type-safe variant definitions for component styling |
| **clsx + tailwind-merge** | Latest | Class merging | Clean conditional class composition, no duplicates |
| **tailwindcss-animate** | 1.0.7+ | Animation utilities | CSS animation classes for Tailwind |
| **@tailwindcss/typography** | 0.5+ | Prose styling | Beautiful default styles for markdown content |

### UI Libraries

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Framer Motion** | 12+ | Animations | Production-grade animations, gestures, layout transitions |
| **Lucide React** | Latest | Icon set | Clean, consistent, tree-shakeable icons |
| **Sonner** | 2+ | Toast notifications | Clean, animated notification system |
| **next-themes** | 0.4+ | Theme management | Dark/light mode with system preference detection |

### State & Data

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Zustand** | 5+ | Global state | Minimal, hooks-based, no boilerplate |
| **react-markdown** | 10+ | Markdown rendering | Rich content display with plugin support |
| **remark-gfm** | 4+ | GFM markdown | Tables, strikethrough, autolinks, task lists |

### Frontend Testing

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Vitest** | 4+ | Test runner | Fast, Vite-native, Jest-compatible API |
| **Testing Library** | 16+ | Component tests | DOM testing, user-event simulation, React render utils |
| **Playwright** | Latest | E2E testing | Cross-browser, reliable, visual testing |

---

## DevOps & Infrastructure

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Cloud Run** | via MCP | Backend deployment | Containerized, auto-scaling, pay-per-request |
| **Firebase Hosting** | Latest | Frontend deployment | Global CDN, instant rollbacks, preview channels |
| **Firebase MCP Server** | Latest | IDE integration | Direct Firestore/Auth access from Antigravity |
| **Cloud Run MCP Server** | Latest | IDE integration | Direct deployment from Antigravity |

---

## Development Environment

| Technology | Version | Purpose | Why This One |
|-----------|---------|---------|-------------|
| **Antigravity IDE** | Latest | AI-native coding | BMAD integration, agent skills, MCP servers |
| **BMAD Method** | 6.2.2+ | Project methodology | Full lifecycle: PRD → Architecture → Stories → Implementation |
| **Pyrefly** | Latest | Python type checker | Meta's type checker, fast, VS Code integrated |
| **ESLint** | 9+ | JS/TS linter | Next.js config, TypeScript-aware rules |
| **Git** | Latest | Version control | Feature branches, conventional commits |

---

## Python Dependency Template

```txt
# Core Framework
fastapi>=0.129.0
uvicorn>=0.41.0
python-dotenv>=1.2.1

# Google AI & Agent Development Kit
google-adk>=1.26.0
google-genai>=1.64.0

# Firebase & GCP
firebase-admin>=7.1.0
google-cloud-discoveryengine>=0.13.12
google-auth>=2.48.0

# Middleware
slowapi>=0.1.9

# SSE (Server-Sent Events)
sse-starlette>=3.2.0

# Testing
pytest>=9.0.2
pytest-asyncio>=0.25.0
httpx>=0.28.1
```

---

## Frontend Dependency Template (package.json)

```json
{
  "dependencies": {
    "@radix-ui/react-dialog": "latest",
    "@radix-ui/react-label": "latest",
    "@radix-ui/react-slot": "latest",
    "@tailwindcss/typography": "^0.5",
    "class-variance-authority": "latest",
    "clsx": "latest",
    "firebase": "^12",
    "framer-motion": "^12",
    "lucide-react": "latest",
    "next": "^16",
    "next-themes": "latest",
    "react": "^19",
    "react-dom": "^19",
    "react-markdown": "^10",
    "remark-gfm": "^4",
    "sonner": "^2",
    "tailwind-merge": "latest",
    "tailwindcss": "^3.4",
    "tailwindcss-animate": "^1",
    "zustand": "^5"
  },
  "devDependencies": {
    "@testing-library/dom": "latest",
    "@testing-library/jest-dom": "latest",
    "@testing-library/react": "latest",
    "@types/node": "^20",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "@vitejs/plugin-react": "latest",
    "eslint": "^9",
    "eslint-config-next": "^16",
    "jsdom": "latest",
    "typescript": "^5",
    "vitest": "^4"
  }
}
```

---

## Update Schedule

Run `/1_check-for-tech-stack-updates` quarterly to audit versions and check for breaking changes.
