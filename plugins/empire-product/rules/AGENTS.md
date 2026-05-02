## Empire product communication

Skills installed under the `empire-product` Claude Code plugin. Findings stay local — never posted to Slack, GitHub, Jira, or external systems.

### Pitches — `pitch`

- For elevator pitches, project intros, or personal "tell me about yourself" prep, use `/empire-product:pitch`
- The skill reads `package.json`, README, and recent commits for repo pitches; produces one-liners, 30-second spoken pitches, or full intros tailored to audience (developer, investor, conference)
- Do not write pitch copy from scratch when the skill is available — output drift erodes brand voice

Conventions:

- Audience MUST be specified or asked: developer, investor, conference, generic
- Output length matches request: one-liner / 30-second / full intro

### Idea validation — `vet`

- For pressure-testing a product idea before building, use `/empire-product:vet` instead of ad-hoc validation
- Skill operates in anti-sycophancy mode: default skepticism, fatal-flaw hypothesis, evidence-based critique
- Output: structured demand signals, competitor teardown, fatal flaws, earned strengths, risks, recommendation (PROCEED / PIVOT / KILL)
- Confidence-tagged: every claim marked `[Confirmed]`, `[Estimated]`, or `[Inferred]`
- Skill never implements — recommendation only

### Competitor mapping — `recon`

- For mapping competitive landscape (pricing, features, positioning) across competitors, use `/empire-product:recon`
- Skill dispatches one agent per competitor in parallel; consolidates a side-by-side matrix with confidence tags and as-of dates
- Ethical scope: public information only — never social engineering, credential stuffing, or unauthorized access
- Output includes gaps, positioning angle, and prioritized action items
- Skill never implements — recommendation only

### Bundled subagents

The plugin ships three fallback subagents that the skills auto-discover at dispatch time:

- `project-idea-validator` — anchor for `vet`
- `competitive-analyst` — anchor for `recon`
- `market-researcher` — market sizing, audience research, trend analysis

If your environment has more specialized subagents installed, the skills will pick the best match available — no configuration needed.
