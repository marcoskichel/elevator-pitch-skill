# marcoskichel/skills

A growing collection of personal Claude Code skills, published as a plugin marketplace and via `npx skills`.

## Install — Claude Code plugin marketplace

Add the marketplace once, then install the skills you want:

```sh
/plugin marketplace add marcoskichel/skills
/plugin install elevator-pitch@marcoskichel-skills
/plugin install team-review@marcoskichel-skills
```

Plugin skills are namespaced under their plugin name. Invoke them as `/elevator-pitch:elevator-pitch` or `/team-review:team-review`. See the per-skill SKILL.md for trigger phrases that Claude will also recognize automatically.

## Install — `npx skills` CLI

```sh
npx skills add marcoskichel/skills     # all skills
npx skills add marcoskichel/skills --skill elevator-pitch
npx skills add marcoskichel/skills --skill team-review
```

## Skills

### elevator-pitch

Generate elevator pitches for repos or people. Reads project context (`package.json`, README, recent commits) and produces one-liners, 30-second spoken pitches, or full intros tailored to audience (developer, investor, conference).

Triggers: "elevator pitch", "pitch this project", "introduce myself", "personal pitch", "how do I pitch myself", "pitch for this repo", "tell me about yourself".

Source: [`plugins/elevator-pitch/skills/elevator-pitch/SKILL.md`](plugins/elevator-pitch/skills/elevator-pitch/SKILL.md)

### team-review

Spawn parallel specialist subagents (architecture, security, performance, tests, generalist) to review a diff or PR, then consolidate findings into a single deduplicated report. Findings stay local — never posted to GitHub.

Triggers: "team review", "have specialists review", "review my changes", "re-review", "another pass", "ask the team", "specialist review".

Source: [`plugins/team-review/skills/team-review/SKILL.md`](plugins/team-review/skills/team-review/SKILL.md)

Append a corresponding entry to `.claude-plugin/marketplace.json`. That's it.

## License

MIT
