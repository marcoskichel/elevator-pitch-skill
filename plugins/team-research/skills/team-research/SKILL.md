---
name: team-research
description: >
  Trigger when user says: "team research", "research approaches", "/team-research",
  "explore options", "investigate approaches", "spawn research team", "research the
  options", "compare approaches", "what are the options", "options analysis", "have
  the team research". Dispatches parallel research subagents to evaluate approaches
  and consolidates findings. Never posts to external systems.
---

<section id="context-gathering">

- Read conversation for problem statement, scope, constraints, success criteria
- Signals to read:
  - Explicit user description of the problem
  - Recent code/files providing technical context
  - Stated constraints (budget, timeline, stack, team size)
  - Prior approaches already ruled out
  - Definition of "good enough" outcome
- If problem statement unclear → ask one clarifying question at a time
- If structured choices help → use `AskUserQuestion` with concrete options
- MUST state inferred problem statement back to user before any dispatch
- MUST get user confirmation on problem statement
- MUST NOT dispatch any agent until problem is confirmed

</section>

<section id="shallow-scan">

- After problem confirmed, dispatch ONE research agent for broad enumeration
- Agent selection for shallow scan:
  - Default → `voltagent-research:research-analyst`
  - Fast lookup / known-solution space → `voltagent-research:search-specialist`
- Shallow agent instructions:
  - Enumerate 3–5 candidate approaches only
  - One short paragraph per approach — no deep evaluation
  - Required output format:
    ```
    1. <Approach Name>
       <One-paragraph description — what it is, how it addresses the problem>

    2. <Approach Name>
       ...
    ```
  - Cap response under 300 words
- Present shallow-scan output to user verbatim before proceeding

</section>

<section id="user-gate">

- After shallow scan, present results and ask user:
  - Which approaches to deep-dive (may pick multiple)
  - Whether to add, remove, or reframe any approach
- MUST wait for explicit user selection before deep dispatch
- MUST NOT infer selection and proceed silently
- If user requests a different approach not in list → add it, confirm updated list

</section>

<section id="agent-selection">

- Pick one deep agent per selected approach
- Selection mapping:
  - General synthesis, multi-source → `voltagent-research:research-analyst`
  - Fast targeted retrieval → `voltagent-research:search-specialist`
  - Comparing products, vendors, libraries → `voltagent-research:competitive-analyst`
  - Audience sizing, market fit → `voltagent-research:market-researcher`
  - Quantitative datasets, benchmarks → `voltagent-research:data-researcher`
  - Peer-reviewed / scientific evidence → `voltagent-research:scientific-literature-researcher`
  - Emerging-tech trajectory → `voltagent-research:trend-analyst`
  - Go/no-go pressure-testing → `voltagent-research:project-idea-validator`
- List chosen agent per approach + one-line rationale BEFORE dispatch
- Allow user to swap agents if desired

</section>

<section id="parallel-deep-dispatch">

- Send single message with multiple `Agent` tool calls (one per approach)
- Each agent receives:
  - Original confirmed problem statement
  - The specific approach assigned to them
  - All known constraints and success criteria
  - Output format instruction (see below)
  - "Do NOT post findings to any external system. Report in chat only."
- Required deep agent output format:
  ```
  Approach: <name>

  Summary: <2-3 sentences>

  Pros:
  - <point>

  Cons:
  - <point>

  Key Evidence / Citations:
  - <source or concrete reference>

  Fit Rating: <High / Medium / Low> — <one sentence rationale>
  ```
- Cap each agent response under 500 words

</section>

<section id="consolidated-report">

- After all deep agents return, produce consolidated report
- Comparison table:
  ```
  | Approach | Pros | Cons | Fit |
  |---|---|---|---|
  ```
- `Conflicts` section — where agents cite contradicting evidence; state each side
- `Recommended approach` — prioritized pick with rationale; cite supporting evidence
- MUST cite sources where agents returned citations
- MUST present report then stop; ask user which direction to pursue
- MUST NOT begin implementation

</section>

<section id="guardrails">

- MUST gather and confirm problem context before any agent dispatch
- MUST clarify ambiguity before shallow scan
- MUST confirm shallow results with user before deep dispatch
- MUST dispatch deep agents in parallel (single message, multiple tool uses)
- MUST keep all findings local in chat only
- MUST NOT post to Slack, GitHub, Jira, or any external system unless user explicitly authorizes
- MUST NOT implement chosen approach — recommendation only
- MUST NOT proceed through any gate without explicit user confirmation

</section>
