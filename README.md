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

<!-- prettier-ignore-start -->
> [!NOTE]
> **Optional but recommended.** Run `/empire-rules:sync-rules` after installing to wire the skill routing rules into your `AGENTS.md` or `~/.claude/CLAUDE.md`. Claude routes more reliably with them.
<!-- prettier-ignore-end -->

## Plugins

| Plugin                                                 | What it does                                                                                                                                |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| [`empire`](plugins/empire-meta/README.md)              | Meta bundle. Installs `empire-git`, `empire-dev`, `empire-research`, and `empire-product` together.                                         |
| [`empire-git`](plugins/empire-git/README.md)           | Git workflow: parallel worktree lifecycle (`open`, `close`, `merge`, `list`, `cleanup`, `help`) and canonical `pr-description` templating.  |
| [`empire-dev`](plugins/empire-dev/README.md)           | Code `team-review` skill plus 11 bundled dev subagents (generalist review, paradigms, domain experts).                                      |
| [`empire-research`](plugins/empire-research/README.md) | Open-ended `explore` and closed `compare` skills with parallel agent dispatch and consolidated reports.                                     |
| [`empire-product`](plugins/empire-product/README.md)   | Product comms and intelligence: `pitch` (elevator pitch), `vet` (idea pressure-test), `recon` (competitor matrix). Three bundled subagents. |
| [`empire-rules`](plugins/empire-rules/README.md)       | Utility: `/empire-rules:sync-rules` reconciles per-plugin routing snippets into the project's `AGENTS.md`. Auto-installed as a dependency.  |

Skills are namespaced by plugin and invoked as `/<plugin>:<skill>`, e.g. `/empire-git:worktree-open`, `/empire-dev:team-review`, `/empire-research:explore`, `/empire-research:compare`, `/empire-product:pitch`, `/empire-product:vet`, `/empire-product:recon`. Claude also auto-routes based on the trigger phrases listed in each skill's `SKILL.md`. To wire those routing rules into a project's `AGENTS.md`, run `/empire-rules:sync-rules` from the repo root.

## Good companions

Plugins that pair well with empire:

- [`superpowers@claude-plugins-official`](https://github.com/anthropics/skills) — discipline skills (TDD, debugging, brainstorming, planning, requesting code review). Pairs with `empire-git` for the commit/PR loop and with `empire-dev` for review rigor.

  ```sh
  /plugin install superpowers@claude-plugins-official
  ```

- [`voltagent-lang@voltagent-subagents`](https://github.com/VoltAgent/awesome-claude-code-subagents) — language-specialist subagents (TypeScript, Python, Rust, Go, Swift, Kotlin, and more). `empire-dev:team-review` auto-discovers them and dispatches the right specialist per file when present.

  ```sh
  /plugin marketplace add VoltAgent/awesome-claude-code-subagents
  /plugin install voltagent-lang@voltagent-subagents
  ```

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md)

## License

MIT
