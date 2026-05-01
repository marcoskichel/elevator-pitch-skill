# empire

Claude Code skill plugins for the solo founder commanding a one-person empire.

You're the CEO. The skills are your staff — review your PRs, research approaches, draft pitches, run parallel branches without losing your place. Solo on paper. Crewed in practice.

This repo is a Claude Code [plugin marketplace](https://code.claude.com/docs/en/plugin-marketplaces). It exposes one meta plugin (`empire`) plus three domain plugins, each focused on one part of the workflow. Install the bundle to get everything, or pick the parts you want.

## Install

Add the marketplace once:

```sh
/plugin marketplace add marcoskichel/empire
```

Then install the full bundle:

```sh
/plugin install empire@empire
```

## Plugins

| Plugin                                               | What it does                                                                                                                               |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| [`empire`](plugins/empire-meta/README.md)            | Meta bundle. Installs `empire-git`, `empire-team`, and `empire-product` together.                                                          |
| [`empire-git`](plugins/empire-git/README.md)         | Git workflow: parallel worktree lifecycle (`open`, `close`, `merge`, `list`, `cleanup`, `help`) and canonical `pr-description` templating. |
| [`empire-team`](plugins/empire-team/README.md)       | Parallel agentic collaboration: dispatch specialist subagents for code `review` and approach `research`, then consolidate findings.        |
| [`empire-product`](plugins/empire-product/README.md) | Product communication: elevator `pitch` for repos and people (more to come — competitive analysis, docs).                                  |

Skills are namespaced by plugin and invoked as `/<plugin>:<skill>`, e.g. `/empire-git:worktree-open`, `/empire-team:review`, `/empire-product:pitch`. Claude also auto-routes based on the trigger phrases listed in each skill's `SKILL.md`.

## Contributing

Format and security hooks run via [`pre-commit`](https://pre-commit.com). One-time setup:

```sh
brew install pre-commit
pre-commit install
```

After that, every `git commit` runs:

- `prettier` — markdown / YAML / JSON formatting
- `shfmt` — shell script formatting (`-i 2 -ci -bn`)
- `shellcheck` — shell script linting / security
- `actionlint` — GitHub Actions workflow linting (catches `${{ github.event.* }}` injection)
- `gitleaks` — secret scanning
- end-of-file / trailing-whitespace / merge-conflict / JSON / YAML basics

CI mirrors the same checks on every push and PR via [`.github/workflows/validate.yml`](.github/workflows/validate.yml).

When adding a new skill, see [`AGENTS.md`](AGENTS.md) for the layout, frontmatter rules, and conventions. Per-plugin READMEs link directly to each skill's `SKILL.md`.

## License

MIT
