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

Generate elevator pitches for repos or people. Detects mode (repo vs personal), reads project context (`package.json`, `README.md`, recent commits) when pitching a repo, asks for the gaps it can't infer (audience, format, proof points), and produces a one-liner, a 30-second spoken version, or a longer context-specific pitch.

**Triggers:** "elevator pitch", "pitch this project", "introduce myself", "personal pitch", "how do I pitch myself", "pitch for this repo", "tell me about yourself", "describe this project", "intro paragraph", "tagline", "one-liner", "GitHub repo description", "what does this do".

```mermaid
flowchart TD
  ask[Detect mode: repo or personal] --> context[Read context: package.json, README, git log]
  context --> gaps[Ask for audience, format, proof points]
  gaps --> framework[Pick framework: one-liner, 30s, conference, investor]
  framework --> draft[Draft with hook, power verbs, single proof point]
  draft --> output[Output annotated versions]
```

**Source:** [`skills/pitch/SKILL.md`](skills/pitch/SKILL.md)

### `vet`

Pressure-test a product idea with brutal honesty. Default stance is skeptical: assume a fatal flaw until evidence proves otherwise. The skill confirms the pitch and assumptions, dispatches a validator agent (with optional competitor research) under web-search preconditions, and produces a structured report with demand signals, competitor teardown, fatal flaws, risks, and a `PROCEED / PIVOT / KILL / INSUFFICIENT_DATA` recommendation. Confidence-tagged.

**Triggers:** "vet idea", "validate idea", "go no go", "pressure test", "is this idea good", "kill the idea", "should I build this", "fatal flaw check", "stress test the idea", "brutal honesty on this idea".

```mermaid
flowchart TD
  pitch[Confirm pitch + assumptions] --> precond[Verify web-search capability]
  precond --> roster[Pick validator agent, confirm]
  roster --> dispatch[Dispatch with anti-sycophancy framing]
  dispatch --> research[Validator: demand signals, competitor teardown]
  research --> verdict[Fatal flaws, strengths, risks, recommendation]
  verdict --> tag[Apply Confirmed / Estimated / Inferred tags]
  tag --> gate[Present and wait for user decision]
```

**Source:** [`skills/vet/SKILL.md`](skills/vet/SKILL.md)

### `recon`

Map the competitive landscape across the dimensions that matter for a positioning or product decision. Dispatches one agent per competitor in parallel, scoped to publicly available info only (no social engineering). Consolidates a side-by-side matrix with `[Confirmed]` / `[Estimated]` / `[Inferred]` tags and `As of` dates, calls out gaps, and suggests a positioning angle.

**Triggers:** "competitor analysis", "compare competitors", "competitor matrix", "competitor research", "feature gap", "scout competitors", "size up competition", "pricing comparison vs competitors", "positioning analysis", "competitive landscape".

```mermaid
flowchart TD
  inputs[Confirm competitors, dimensions, decision goal] --> precond[Verify web-search capability]
  precond --> roster[Pick one scout per competitor, confirm]
  roster --> dispatch[Parallel Agent calls, public info only]
  dispatch --> data[Per-competitor data: features, pricing, positioning]
  data --> matrix[Build side-by-side matrix with confidence + As of]
  matrix --> output[Gaps, positioning angle, action items, caveats]
  output --> stop[Stop and ask which actions to pursue]
```

**Source:** [`skills/recon/SKILL.md`](skills/recon/SKILL.md)

## Bundled agents

| Agent                    | Use                                                           |
| ------------------------ | ------------------------------------------------------------- |
| `project-idea-validator` | Brutal go/no-go pressure-testing of ideas (anchor for `vet`)  |
| `competitive-analyst`    | Vendor / competitor / option comparisons (anchor for `recon`) |
| `market-researcher`      | Market sizing, audience research, trend analysis              |

All three skills auto-discover whatever specialist subagents are installed. If your environment has more specialized subagents from another marketplace, the skills will use them.

## Upstream attribution

Source and license: [`agents/NOTICE.md`](agents/NOTICE.md).
