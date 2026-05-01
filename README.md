# Empire

Claude Code skills that staff your one-person company.

You're the CEO. You're also QA, support, and the intern who fetches coffee. The skills handle everyone else: a coder, a reviewer, a researcher, a PR scribe, a pitch writer, and a parallel-branch wrangler. Solo on paper. Crewed in practice.

## Hire the crew

Add the marketplace once:

```sh
/plugin marketplace add marcoskichel/empire
```

Install the full bundle:

```sh
/plugin install empire@empire
```

Or hire individual departments:

```sh
/plugin install empire-git@empire
/plugin install empire-dev@empire
/plugin install empire-research@empire
/plugin install empire-product@empire
```

## Plugins

| Plugin                                                 | What it does                                                                                                                               |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------ |
| [`empire`](plugins/empire-meta/README.md)              | Meta bundle. Installs `empire-git`, `empire-dev`, `empire-research`, and `empire-product` together.                                        |
| [`empire-git`](plugins/empire-git/README.md)           | Git workflow: parallel worktree lifecycle (`open`, `close`, `merge`, `list`, `cleanup`, `help`) and canonical `pr-description` templating. |
| [`empire-dev`](plugins/empire-dev/README.md)           | Code `review` skill plus 11 bundled dev subagents (generalist review, paradigms, domain experts).                                          |
| [`empire-research`](plugins/empire-research/README.md) | Approach `research` skill plus three bundled research subagents (synthesis, comparative, idea validation).                                 |
| [`empire-product`](plugins/empire-product/README.md)   | Product communication: elevator `pitch` for repos and people.                                                                              |
| [`empire-rules`](plugins/empire-rules/README.md)       | Utility: `/empire-rules:sync-rules` reconciles per-plugin routing snippets into the project's `AGENTS.md`. Auto-installed as a dependency. |

Skills are namespaced by plugin and invoked as `/<plugin>:<skill>`, e.g. `/empire-git:worktree-open`, `/empire-dev:review`, `/empire-research:research`, `/empire-product:pitch`. Claude also auto-routes based on the trigger phrases listed in each skill's `SKILL.md`. To wire those routing rules into a project's `AGENTS.md`, run `/empire-rules:sync-rules` from the repo root.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md)

## License

MIT
