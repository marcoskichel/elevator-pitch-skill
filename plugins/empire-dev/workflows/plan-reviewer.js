const meta = {
  name: "plan-reviewer",
  description:
    "Adversarial plan-vs-spec review for /empire-dev:plan-reviewer — three fixed-angle reviewers (contradictions, coverage, ambiguity) fan out in parallel, one verifier per non-nit finding dispatches eagerly, confirmed findings grouped by issue type in JS.",
  whenToUse:
    "Invoked by /empire-dev:plan-reviewer when a JS workflow runner is available. Requires args {plan, spec}; optional {context, reviewerModel, verifierModel}. Recommendation-only: never edits files, never posts to GitHub.",
  phases: [
    { title: "Review", detail: "three adversarial angles in parallel" },
    { title: "Verify", detail: "one verifier per non-nit finding, eager" },
  ],
};

const REVIEWER_WORK_MINUTES = 8;
const VERIFIER_WORK_MINUTES = 3;
const GRACE_MINUTES = 3;
const MINUTE_MS = 60 * 1000;
const REVIEWER_TIMEOUT_MS = (REVIEWER_WORK_MINUTES + GRACE_MINUTES) * MINUTE_MS;
const VERIFIER_TIMEOUT_MS = (VERIFIER_WORK_MINUTES + GRACE_MINUTES) * MINUTE_MS;

const BUDGET_NOTE = (workMinutes) =>
  "## Budget\nYou have ~" +
  workMinutes +
  " minutes of work time plus a " +
  GRACE_MINUTES +
  "-minute grace period reserved for emitting your final structured output. " +
  "When your work window closes, stop investigating and return what you have — " +
  "a partial result beats a timeout, which loses everything.\n\n";

const ISSUE_TYPES = ["contradiction", "omission", "unsupported", "ambiguity"];
const SEVERITIES = ["blocker", "should-fix", "nit"];

const FINDINGS_SCHEMA = {
  type: "object",
  required: ["findings"],
  properties: {
    findings: {
      type: "array",
      items: {
        type: "object",
        required: ["planRef", "issueType", "severity", "problem", "suggestion"],
        properties: {
          planRef: { type: "string" },
          specRef: { type: "string" },
          issueType: { type: "string", enum: ISSUE_TYPES },
          severity: { type: "string", enum: SEVERITIES },
          problem: { type: "string" },
          suggestion: { type: "string" },
        },
      },
    },
  },
};

const VERDICT_SCHEMA = {
  type: "object",
  required: ["verdict", "rationale"],
  properties: {
    verdict: { type: "string", enum: ["blocker", "should-fix", "nit", "invalid"] },
    rationale: { type: "string" },
  },
};

// args can arrive as a JSON string; parse once so field access always works.
const input = typeof args === "string" ? JSON.parse(args) : args;

const plan = input?.plan ?? "";
const spec = input?.spec ?? "";
const context = input?.context ?? "";
const reviewerModel = input?.reviewerModel ?? "sonnet";
const verifierModel = input?.verifierModel ?? "haiku";

if (!plan || !spec) {
  return { error: "plan-reviewer requires args {plan, spec} as non-empty strings." };
}

const ANGLES = [
  {
    name: "contradiction-hunter",
    issueTypes: ["contradiction"],
    brief:
      "Hunt for plan steps that are WRONG: they contradict the spec, misread a requirement, " +
      "get a name/interface/behavior/constraint factually incorrect, or would produce an outcome " +
      "the spec forbids. For each hit, quote the plan text, quote the spec text it violates, and " +
      "state exactly why they conflict. issueType is always 'contradiction'.",
  },
  {
    name: "coverage-auditor",
    issueTypes: ["omission", "unsupported"],
    brief:
      "Audit coverage in both directions. Direction 1 — omission: walk the spec requirement by " +
      "requirement; any requirement, constraint, edge case, or deliverable with no plan step that " +
      "satisfies it is an 'omission' (planRef = the plan section where it should live, or 'plan-wide'; " +
      "specRef = the uncovered requirement). Direction 2 — unsupported: walk the plan step by step; " +
      "any step, feature, or decision with no basis in the spec is 'unsupported' — the plan is " +
      "inventing scope the spec never asked for.",
  },
  {
    name: "ambiguity-prober",
    issueTypes: ["ambiguity"],
    brief:
      "Probe for plan parts too vague to implement deterministically: steps where two reasonable " +
      "implementers would build different things, undefined terms, unstated file paths or interfaces, " +
      "'handle X appropriately' hand-waving, missing acceptance criteria, or unresolved decisions " +
      "deferred to the implementer. For each, state the concrete question the plan fails to answer. " +
      "issueType is always 'ambiguity'.",
  },
];

const CONTEXT_BLOCK = context ? "## Additional context\n" + context + "\n\n" : "";

const DOCS_BLOCK =
  "## Spec (source of truth)\n" + spec + "\n\n## Plan (under review)\n" + plan + "\n\n";

const REVIEW_PROMPT = (a) =>
  "## Adversarial plan reviewer: " +
  a.name +
  "\n\n" +
  "You are one of three adversarial reviewers inspecting an implementation plan against its spec. " +
  "The spec is the source of truth; the plan is on trial. Your job is to find real problems, not to " +
  "approve. Assume the plan author made mistakes and hunt for them — but every finding must survive " +
  "scrutiny: cite the exact plan text (planRef) and, where applicable, the exact spec text (specRef). " +
  "A finding you cannot ground in quoted text is not a finding.\n\n" +
  "## Your angle\n" +
  a.brief +
  "\n\n" +
  "Stay in your lane: report ONLY issueType values " +
  JSON.stringify(a.issueTypes) +
  " — other angles cover the rest.\n\n" +
  "## Severity rubric\n" +
  "- blocker: implementing the plan as written produces the wrong system or misses a spec requirement\n" +
  "- should-fix: real gap or risk, but a competent implementer would likely recover\n" +
  "- nit: minor imprecision; safe to ignore\n\n" +
  BUDGET_NOTE(REVIEWER_WORK_MINUTES) +
  CONTEXT_BLOCK +
  DOCS_BLOCK +
  "## Task\n" +
  "- Per finding: planRef (quoted plan text or section), specRef (quoted spec text, when applicable), " +
  "issueType, severity, problem (what is wrong), suggestion (concrete fix to the plan).\n" +
  "- No findings for your angle is a valid result — return an empty list rather than manufacturing issues.\n" +
  "- Do NOT edit files. Do NOT post anywhere. Structured output only.";

const VERIFY_PROMPT = (f) =>
  "## Finding verifier\n\n" +
  "Adjudicate exactly ONE plan-review finding against the spec and plan inlined below. " +
  "Judge ONLY this finding — never report other issues.\n\n" +
  BUDGET_NOTE(VERIFIER_WORK_MINUTES) +
  DOCS_BLOCK +
  "## Finding\n" +
  "- issueType: " +
  f.issueType +
  "\n- planRef: " +
  f.planRef +
  "\n" +
  (f.specRef ? "- specRef: " + f.specRef + "\n" : "") +
  "- problem: " +
  f.problem +
  "\n- suggestion: " +
  f.suggestion +
  "\n\n## Rubric\n" +
  "- blocker: confirmed — implementing the plan as written produces the wrong system or misses a spec requirement\n" +
  "- should-fix: confirmed real gap or risk, but recoverable during implementation\n" +
  "- nit: confirmed but minor imprecision only\n" +
  "- invalid: the quoted refs do not support the claim, the plan actually covers it, or the spec permits it\n\n" +
  "## Task\n" +
  "- verdict: exactly one rubric value.\n- rationale: one sentence.\n" +
  "- Do NOT edit files. Do NOT post anywhere. Structured output only.";

log("Reviewing plan with 3 adversarial angles: " + ANGLES.map((a) => a.name).join(", "));

const registry = [];
const verifierRuns = [];

const dispatchVerifier = (entry) => {
  verifierRuns.push(
    agent(VERIFY_PROMPT(entry.finding), {
      label: "verify:" + entry.finding.issueType + ":" + entry.finding.planRef.slice(0, 40),
      phase: "Verify",
      model: verifierModel,
      schema: VERDICT_SCHEMA,
      timeout: VERIFIER_TIMEOUT_MS,
    })
      .then((v) => {
        entry.verdict = v || null;
      })
      // ponytail: abort/budget rejections resolve to an unverified finding
      // instead of an unhandled rejection that kills the host process
      .catch(() => {}),
  );
};

const reviewers = await parallel(
  ANGLES.map(
    (a) => () =>
      agent(REVIEW_PROMPT(a), {
        label: "review:" + a.name,
        phase: "Review",
        schema: FINDINGS_SCHEMA,
        model: reviewerModel,
        timeout: REVIEWER_TIMEOUT_MS,
      }).then((r) => {
        if (!r) return null;
        const findings = (r.findings ?? []).filter(
          (f) =>
            f && f.planRef && a.issueTypes.includes(f.issueType) && SEVERITIES.includes(f.severity),
        );
        let dispatched = 0;
        // ponytail: no cross-angle dedup — angles have disjoint issueTypes,
        // add fuzzy merge only if duplicate findings show up in practice
        for (const f of findings) {
          const entry = {
            finding: { ...f },
            angle: a.name,
            verdict: null,
            skipVerify: f.severity === "nit",
          };
          registry.push(entry);
          if (!entry.skipVerify) {
            dispatchVerifier(entry);
            dispatched++;
          }
        }
        log(
          a.name +
            ": " +
            findings.length +
            " findings, " +
            dispatched +
            " verifiers dispatched (nits skip verification)",
        );
        return { name: a.name, findingCount: findings.length };
      }),
  ),
);

const returned = reviewers.filter(Boolean);
if (returned.length === 0) return { error: "no reviewer returned findings" };

await Promise.all(verifierRuns);

const confirmed = [];
const rejected = [];
const unverified = [];

for (const e of registry) {
  const row = {
    planRef: e.finding.planRef,
    specRef: e.finding.specRef ?? "",
    issueType: e.finding.issueType,
    severity: e.verdict ? e.verdict.verdict : e.finding.severity,
    problem: e.finding.problem,
    suggestion: e.finding.suggestion,
    angle: e.angle,
  };
  if (e.verdict && e.verdict.verdict === "invalid") {
    rejected.push({ ...row, severity: e.finding.severity, rationale: e.verdict.rationale });
  } else if (!e.verdict && !e.skipVerify) {
    unverified.push(row);
  } else {
    confirmed.push(row);
  }
}

const order = (rows) =>
  rows.sort(
    (a, b) =>
      SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity) ||
      ISSUE_TYPES.indexOf(a.issueType) - ISSUE_TYPES.indexOf(b.issueType),
  );

log(
  "Done: " +
    confirmed.length +
    " confirmed, " +
    rejected.length +
    " rejected" +
    (unverified.length ? ", " + unverified.length + " unverified" : ""),
);

return {
  reviewers: returned,
  confirmed: order(confirmed),
  rejected,
  unverified: order(unverified),
  stats: {
    findings: registry.length,
    verified: registry.filter((e) => e.verdict).length,
    rejected: rejected.length,
  },
};
