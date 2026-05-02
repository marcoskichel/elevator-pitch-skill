# empire-product

Product communication and intelligence: pitches, idea validation, and competitor mapping. Three skills, three bundled subagents.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-product@empire
```

Or install the full empire bundle (which includes this plugin):

```sh
/plugin install empire@empire
```

## Skills

### `pitch`

Generate elevator pitches for repos or people. Reads project context (`package.json`, README, recent commits) and produces one-liners, 30-second spoken pitches, or full intros tailored to audience (developer, investor, conference).

Triggers: "elevator pitch", "pitch this project", "introduce myself", "personal pitch", "how do I pitch myself", "pitch for this repo", "tell me about yourself", "describe this project", "intro paragraph", "tagline", "one-liner", "GitHub repo description", "what does this do".

Source: [`skills/pitch/SKILL.md`](skills/pitch/SKILL.md)

### `vet`

Pressure-test a product idea with brutal honesty. Web research for competitors and demand, fatal-flaw hypothesis, anti-sycophancy mode, structured go/no-go output with suggested pivots and MVP scope. Confidence-tagged.

Triggers: "vet idea", "validate idea", "go no go", "pressure test", "is this idea good", "kill the idea", "should I build this", "fatal flaw check", "stress test the idea", "brutal honesty on this idea".

Source: [`skills/vet/SKILL.md`](skills/vet/SKILL.md)

### `recon`

Map the competitive landscape across the dimensions that matter for a positioning or product decision. Dispatches one agent per competitor in parallel, consolidates a side-by-side matrix with `[Confirmed]` / `[Estimated]` / `[Inferred]` confidence tags, calls out gaps and a positioning angle.

Triggers: "competitor analysis", "compare competitors", "competitor matrix", "competitor research", "feature gap", "scout competitors", "size up competition", "pricing comparison vs competitors", "positioning analysis", "competitive landscape".

Source: [`skills/recon/SKILL.md`](skills/recon/SKILL.md)

## Bundled agents

| Agent                    | Use                                                           |
| ------------------------ | ------------------------------------------------------------- |
| `project-idea-validator` | Brutal go/no-go pressure-testing of ideas (anchor for `vet`)  |
| `competitive-analyst`    | Vendor / competitor / option comparisons (anchor for `recon`) |
| `market-researcher`      | Market sizing, audience research, trend analysis              |

All three skills auto-discover whatever specialist subagents are installed. If your environment has more specialized subagents from another marketplace, the skills will use them.

Upstream attribution: [`agents/NOTICE.md`](agents/NOTICE.md).
