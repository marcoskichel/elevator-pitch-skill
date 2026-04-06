# elevator-pitch

A Claude Code skill that generates elevator pitches for repositories and people.

## Install

```sh
npx skills add marcoskichel/elevator-pitch-skill
```

## Usage

Trigger in Claude Code:

```
/elevator-pitch
```

Or just describe what you need — Claude will detect the right mode automatically.

## Repo pitches

Run it inside any repo and it reads the project context first — `package.json`, `README`, recent commits — then generates:

- **One-liner** — ready to paste into your GitHub description or `package.json`
- **30-second spoken** — for demos, conference intros, or dev meetups
- **Context-specific** — investor meeting, developer networking, or npm/GitHub listing

```
"pitch this repo for a developer conference"
"generate a one-liner for my package.json"
"write an investor pitch for this project"
```

## Personal pitches

Also works for pitching yourself:

- **Networking event** — "what do you do?" short form
- **Job interview** — Present → Past → Future arc
- **Investor meeting** — problem at scale + traction + explicit ask
- **Conference intro** — 15-second counterintuitive hook

```
"generate my elevator pitch for a job interview"
"how do I introduce myself at a conference?"
"give me a 30-second personal pitch"
```

## How it works

Applies research-backed frameworks (PSPA, Present-Past-Future) with enforced rules:

- Opens with the problem, not the name or title
- One number or named result — flags `[PROOF POINT NEEDED]` if none available
- Power verbs only — no "responsible for" or "passionate about"
- Always closes with a door-opener, never a thud

## License

MIT
