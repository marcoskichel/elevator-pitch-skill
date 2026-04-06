---
name: elevator-pitch
description: Generate a personal elevator pitch or a repository/project pitch. Use when user asks for "elevator pitch", "pitch this project", "introduce myself", "personal pitch", "how do I pitch myself", "pitch for this repo", or wants a "tell me about yourself" answer.
---

# Elevator Pitch Generator

## When to use

- User asks for a personal elevator pitch or intro
- User asks to pitch a project, repo, or library
- User is preparing for networking event, job interview, investor meeting, or conference
- User wants a "tell me about yourself" or "what does this do?" answer

## Mode Detection

Determine mode from user request:

| Signal | Mode |
|---|---|
| "pitch myself", "introduce myself", "tell me about yourself" | Personal |
| "pitch this project/repo/library", "elevator pitch for X" | Repo |
| Ambiguous + active repo in context | Ask: "Personal pitch or pitch for this project?" |

---

## Personal Pitch

### 1. Gather context

Ask only what's missing — one question at a time:

- Current role and domain (specific: what problems, for whom)
- One concrete proof point — a number, result, or scale signal
- Context: networking / job interview / investor meeting / conference intro
- What they want next — a role, conversation, intro, or follow-up meeting

Skip questions if user has already provided context.

### 2. Framework by context

| Context | Framework | Length |
|---|---|---|
| Networking event | Who I help → How → Why it matters → Hook question | 30–45s |
| Job interview | Present → Past → Future → close to the role | 60–90s |
| Investor meeting | Problem at scale → Solution → Traction → Explicit ask | 60s |
| Conference intro | Counterintuitive claim → what you're curious about here | 15–20s |

IMPORTANT: "What do you do?" and "Tell me about yourself" are different. For casual networking, generate the short-form version first.

### 3. Output

Produce three versions:

- **30-second** — Problem → Solution → Ask
- **60-second** — Problem → Solution → Proof → Ask
- **Context-specific** — adapted to context from the table above

---

## Repo Pitch

### 1. Gather context

Read from the repo first — don't ask what can be inferred:

- Read `package.json` (name, description, keywords)
- Read `README.md` (what it does, why it exists)
- Run `git log --oneline -10` to understand recent trajectory
- Identify: what problem it solves, who it's for, one architectural decision that signals taste

Ask only what can't be inferred:
- Target audience (if unclear): developers / teams / enterprises / AI builders
- Context: developer networking / conference demo / investor meeting / npm/GitHub description
- Any traction or proof point: installs, teams using it, benchmark results

### 2. Framework by context

| Context | Framework | Length |
|---|---|---|
| Developer networking | Problem image → What it does → One design decision → Hook question | 30–45s |
| Conference / demo day | Counterintuitive claim → Solution → Architecture hook | 20–30s |
| Investor meeting | Problem at scale → Solution → Traction → Explicit ask | 60s |
| npm / GitHub description | Ultra-concise one-liner — problem + differentiator, no fluff | 1 sentence |

### 3. Output

Produce three versions:

- **One-liner** — fits in package.json `description` or GitHub repo description
- **30-second spoken** — Problem → Solution → Hook question
- **Context-specific** — adapted to the chosen context

---

## Rules (both modes)

- Open with the problem, not the name or title
- Use one of three hook types:
  - Problem image: "Every agent you build starts with amnesia..."
  - Tension/reversal: "We kept hitting X, so we built Y..."
  - Unusual claim: something that earns a follow-up question
- Power verbs only: built, shipped, fixed, cut, grew, decided, finished
- Avoid: "responsible for", "worked on", "passionate about", "it's a library that..."
- Include exactly one number or named result — flag `[PROOF POINT NEEDED]` if none available
- End with curiosity opener, soft signal, or direct ask — never a thud
- No insider jargon — translate mechanism to impact

IMPORTANT: Pitch must sound fluent, not scripted. Contractions, one casual phrase, avoid relentlessly parallel structure.

Annotate each version with one sentence explaining the structural choice made.
