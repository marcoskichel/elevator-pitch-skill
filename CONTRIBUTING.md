# Contributing

## Local setup

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

## Adding a new skill

See [`AGENTS.md`](AGENTS.md) for the layout, frontmatter rules, and conventions. Per-plugin READMEs link directly to each skill's `SKILL.md`.

Never bypass hooks with `--no-verify`. If a hook fails, fix the underlying issue.
