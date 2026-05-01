# empire-agents

Bundled fallback subagents covering code review, paradigm specialists, domain experts, and research roles. Pairs with `empire-team`'s `review` and `research` skills, which auto-discover whatever specialist subagents are installed and pick the best match per task.

Part of the [empire](../../README.md) marketplace.

## Install

```sh
/plugin marketplace add marcoskichel/empire
/plugin install empire-agents@empire
```

Or install the full empire bundle (which includes this plugin):

```sh
/plugin install empire@empire
```

## Agents

Code review:

| Agent                  | Use                                              |
| ---------------------- | ------------------------------------------------ |
| `code-reviewer`        | Generalist code review (security, perf, quality) |
| `debugger`             | Root-cause analysis of errors and test failures  |
| `test-automator`       | Test strategy, frameworks, TDD, CI quality gates |
| `security-auditor`     | Auth, crypto, OWASP, threat modeling, compliance |
| `architect-review`     | Clean architecture, microservices, DDD, SOLID    |
| `performance-engineer` | Profiling, bottlenecks, caching, observability   |

Paradigm specialists:

| Agent                           | Use                                                       |
| ------------------------------- | --------------------------------------------------------- |
| `functional-programming-expert` | Purity, immutability, totality, composition, ADT modeling |
| `concurrency-reviewer`          | Race conditions, deadlocks, async / await correctness     |
| `type-system-expert`            | Type design, invariants, generics, GADTs, branded types   |

Domain specialists:

| Agent                  | Use                                                  |
| ---------------------- | ---------------------------------------------------- |
| `blockchain-developer` | Smart contracts, DeFi, Web3, gas optimization, audit |
| `ai-engineer`          | LLM apps, RAG, agents, prompts, vector search        |

Research:

| Agent                    | Use                                           |
| ------------------------ | --------------------------------------------- |
| `research-analyst`       | Multi-source research synthesis and reporting |
| `competitive-analyst`    | Vendor / library / option comparisons         |
| `project-idea-validator` | Brutal go/no-go pressure-testing of ideas     |

## How they're used

Agents register automatically on install. They appear in `/agents` and are callable via the `Agent` tool's `subagent_type` parameter. The `empire-team:review` and `empire-team:research` skills auto-discover them at dispatch time — no skill configuration required.

If your environment has more specialized subagents installed (from other marketplaces), the skills will pick the best match available.

## Attribution

See [`agents/NOTICE.md`](agents/NOTICE.md) for full upstream attribution and modification details. All bundled agents are MIT-licensed.
