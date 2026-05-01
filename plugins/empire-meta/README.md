# empire (meta)

Bundle plugin: installs the full empire skill suite in one shot.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire@empire
```

That's it — this plugin contributes no skills of its own. It declares `empire-git`, `empire-team`, and `empire-product` as dependencies, and Claude Code installs them automatically.

## Bundled plugins

| Plugin                                          | Purpose                                                                                       |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [`empire-git`](../empire-git/README.md)         | Worktree lifecycle (`open`, `close`, `merge`, `list`, `cleanup`, `help`) and `pr-description` |
| [`empire-team`](../empire-team/README.md)       | Parallel agentic collaboration: `review`, `research`                                          |
| [`empire-product`](../empire-product/README.md) | Product communication: `pitch` (and more to come)                                             |

## Want a subset?

Install any sub-plugin individually instead of the bundle:

```sh
/plugin install empire-git@empire
/plugin install empire-team@empire
/plugin install empire-product@empire
```
