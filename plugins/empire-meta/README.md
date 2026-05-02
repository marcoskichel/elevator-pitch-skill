# empire (meta)

Bundle plugin: installs the full empire skill suite in one shot.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire@empire
```

That's it — this plugin contributes no skills of its own. It declares `empire-git`, `empire-dev`, `empire-research`, and `empire-product` as dependencies, and Claude Code installs them automatically.

## Bundled plugins

| Plugin                                            | Purpose                                                                                       |
| ------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [`empire-git`](../empire-git/README.md)           | Worktree lifecycle (`open`, `close`, `merge`, `list`, `cleanup`, `help`) and `pr-description` |
| [`empire-dev`](../empire-dev/README.md)           | Code `review` skill plus 11 bundled dev subagents (code review, paradigms, domain experts)    |
| [`empire-research`](../empire-research/README.md) | `explore` (open-ended) and `compare` (closed) research skills with parallel agent dispatch    |
| [`empire-product`](../empire-product/README.md)   | `pitch`, `vet` (idea pressure-test), `recon` (competitor matrix) plus three bundled subagents |

## Want a subset?

Install any sub-plugin individually instead of the bundle:

```sh
/plugin install empire-git@empire
/plugin install empire-dev@empire
/plugin install empire-research@empire
/plugin install empire-product@empire
```
