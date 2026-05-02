# empire-product

Skills installed under the `empire-product` Claude Code plugin.

- `/empire-product:vet` and `/empire-product:recon` are recommendation-only — never apply edits, commit, or run side effects.
- `/empire-product:vet` operates in anti-sycophancy mode: default skepticism, fatal-flaw hypothesis, evidence-based critique. Output recommendation: PROCEED / PIVOT / KILL.
- `/empire-product:recon` is restricted to public information — never social engineering, credential stuffing, or unauthorized access.
- For both `vet` and `recon`, every claim MUST be confidence-tagged `[Confirmed]`, `[Estimated]`, or `[Inferred]`.
- Findings stay local — never post to Slack, GitHub, Jira, or external systems.
