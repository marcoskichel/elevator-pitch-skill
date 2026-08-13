export const meta = {
  name: "team-review",
  description:
    "Parallel specialist diff review for /empire-dev:team-review — schema-driven specialist fan-out, eager per-finding verification (verifiers dispatch as each specialist returns, no cross-wave barrier), deterministic consensus tiering in JS.",
  whenToUse:
    "Invoked by /empire-dev:team-review when the Workflow tool is available. Requires args {diff, changedFiles, roster:[{name, persona?, agentType?, model?}]}; optional {intent, vocabulary, adrs, rereviewNote}. Recommendation-only: never edits files, never posts to GitHub.",
  phases: [
    { title: "Review", detail: "one specialist per roster entry" },
    { title: "Verify", detail: "one verifier per non-consensus non-nit finding, eager" },
  ],
};

const CATEGORIES = [
  "correctness",
  "security",
  "performance",
  "architecture",
  "tests",
  "style",
  "docs",
];

const SEVERITIES = ["must-fix", "should-fix", "nit"];

const FINDINGS_SCHEMA = {
  type: "object",
  required: ["findings", "praise"],
  properties: {
    findings: {
      type: "array",
      items: {
        type: "object",
        required: ["file", "startLine", "endLine", "category", "severity", "suggestion"],
        properties: {
          file: { type: "string" },
          startLine: { type: "number" },
          endLine: { type: "number" },
          category: { type: "string", enum: CATEGORIES },
          severity: { type: "string", enum: SEVERITIES },
          suggestion: { type: "string" },
        },
      },
    },
    praise: { type: "array", items: { type: "string" } },
  },
};

const VERDICT_SCHEMA = {
  type: "object",
  required: ["verdict", "rationale"],
  properties: {
    verdict: { type: "string", enum: ["must-fix", "should-fix", "nit", "invalid"] },
    rationale: { type: "string" },
  },
};

// args can arrive as a JSON string; parse once so field access always works.
const input = typeof args === "string" ? JSON.parse(args) : args;

const diff = input?.diff ?? "";
const changedFiles = input?.changedFiles ?? [];
const roster = input?.roster ?? [];
const intent = input?.intent ?? "";
const vocabulary = input?.vocabulary ?? "";
const adrs = input?.adrs ?? "";
const rereviewNote = input?.rereviewNote ?? "";

if (!diff || roster.length < 2) {
  return {
    error:
      "team-review requires args {diff, changedFiles, roster:[{name, agentType?}]} with roster >= 2.",
  };
}

const findingLabel = (f) =>
  f.file + ":" + f.startLine + (f.endLine > f.startLine ? "-" + f.endLine : "");

const sameFinding = (a, b) =>
  a.file === b.file &&
  a.category === b.category &&
  a.startLine <= b.endLine + 5 &&
  b.startLine <= a.endLine + 5;

const mostSevere = (severities) => SEVERITIES.find((s) => severities.includes(s));

const hunkFor = (f) => {
  const lines = diff.split("\n");
  const out = [];
  let file = "";
  let newLine = 0;
  for (const l of lines) {
    if (l.startsWith("+++ b/")) {
      file = l.slice(6);
      continue;
    }
    const h = l.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@/);
    if (h) {
      newLine = parseInt(h[1], 10) - 1;
      continue;
    }
    if (l.startsWith("-")) continue;
    if (l.startsWith("+") || l.startsWith(" ")) newLine++;
    if (file === f.file && newLine >= f.startLine - 15 && newLine <= f.endLine + 15) {
      out.push(l);
    }
  }
  return out.join("\n");
};

const CONTEXT_BLOCK =
  (intent ? "## Author intent\n" + intent + "\n\n" : "") +
  (vocabulary ? "## Project vocabulary (use these terms verbatim)\n" + vocabulary + "\n\n" : "") +
  (adrs ? "## Relevant ADRs\n" + adrs + "\n\n" : "") +
  (rereviewNote ? "## Re-review context\n" + rereviewNote + "\n\n" : "");

const SPEC_PROMPT = (s) =>
  "## Specialist reviewer: " +
  s.name +
  "\n\n" +
  (s.persona ? s.persona + "\n\n" : "") +
  "You are one specialist in a parallel team review. The full diff is inlined below — do NOT re-fetch it; " +
  "use Read/Grep only when a finding depends on code beyond the diff (blast radius).\n\n" +
  "Scope: review what the diff DOES and how it is structured; flag defects AND structural regressions in " +
  "changed lines + their direct blast radius.\n" +
  "Be ambitious. Do not stop at local cleanup — look for the reframing that makes whole branches, helpers, " +
  "modes, or layers disappear. Prefer deleting complexity over rearranging it.\n" +
  "A RESTRUCTURING suggestion needs no cited defect IF it removes more code and concepts than it adds; " +
  "name what disappears. An ADDITIVE suggestion (new file, abstraction, test, doc) MUST cite the specific " +
  "defect in the diff it resolves; no defect cited → drop the finding.\n" +
  "Do not rubber-stamp working code that leaves the codebase messier. Do not flood with nits — omit nit-severity " +
  "findings entirely when you have must-fix findings.\n\n" +
  CONTEXT_BLOCK +
  "## Changed files\n" +
  changedFiles.join("\n") +
  "\n\n## Diff\n```\n" +
  diff +
  "\n```\n\n## Task\n" +
  "- Per finding: file (repo-relative path), startLine/endLine (in the NEW file), category, severity, one concrete suggestion.\n" +
  "- praise: what was done well, short strings.\n" +
  "- Do NOT edit files. Do NOT post to GitHub. Structured output only.";

const VERIFY_PROMPT = (f, hunk) =>
  "## Finding verifier\n\n" +
  "Adjudicate exactly ONE code-review finding. Judge ONLY this finding — never report other issues. " +
  "Judge from the inlined hunk first; use Read/Grep only when the claim depends on code beyond the hunk.\n\n" +
  "## Finding\n`" +
  findingLabel(f) +
  "` [`" +
  f.category +
  "`] — " +
  f.suggestion +
  "\n\n## Diff hunk (±15 lines)\n```\n" +
  (hunk || "(hunk not resolvable from diff — read the file)") +
  "\n```\n\n## Rubric\n" +
  "- must-fix: confirmed defect breaking functionality, security, data integrity, or correctness in the changed lines or their direct blast radius\n" +
  "- should-fix: confirmed real improvement, not urgent; includes a behavior-preserving restructuring that provably removes more code and concepts than it adds\n" +
  "- nit: confirmed but cosmetic/style only\n" +
  "- invalid: claim does not hold up against the diff, OR the proposed restructuring adds more than it removes, OR it changes behavior while claiming not to\n\n" +
  "## Task\n" +
  "- verdict: exactly one rubric value.\n- rationale: one sentence.\n" +
  "- Do NOT edit files. Do NOT post to GitHub. Structured output only.";

log("Reviewing with " + roster.length + " specialists: " + roster.map((s) => s.name).join(", "));

const registry = [];
const verifierRuns = [];

const dispatchVerifier = (entry) => {
  verifierRuns.push(
    agent(VERIFY_PROMPT(entry.finding, hunkFor(entry.finding)), {
      label: "verify:" + findingLabel(entry.finding),
      phase: "Verify",
      model: "haiku",
      schema: VERDICT_SCHEMA,
    }).then((v) => {
      entry.verdict = v || null;
    }),
  );
};

const specialists = await parallel(
  roster.map((s) => () => {
    const opts = {
      label: "review:" + s.name,
      phase: "Review",
      schema: FINDINGS_SCHEMA,
      model: s.model || "sonnet",
    };
    if (s.agentType) opts.agentType = s.agentType;
    return agent(SPEC_PROMPT(s), opts).then((r) => {
      if (!r) return null;
      const findings = (r.findings ?? []).filter(
        (f) => f && f.file && CATEGORIES.includes(f.category) && SEVERITIES.includes(f.severity),
      );
      for (const f of findings) {
        const entry = registry.find((e) => sameFinding(e.finding, f));
        if (entry) {
          entry.count++;
          entry.specialists.push(s.name);
          entry.severities.push(f.severity);
          if (f.suggestion.length > entry.finding.suggestion.length) {
            entry.finding.suggestion = f.suggestion;
          }
          if (entry.skipVerify && f.severity !== "nit") {
            entry.skipVerify = false;
            dispatchVerifier(entry);
          }
        } else {
          const e = {
            finding: { ...f },
            count: 1,
            specialists: [s.name],
            severities: [f.severity],
            verdict: null,
            skipVerify: f.severity === "nit",
          };
          registry.push(e);
          if (!e.skipVerify) dispatchVerifier(e);
        }
      }
      log(s.name + ": " + findings.length + " findings, verifiers dispatched");
      return {
        name: s.name,
        findingCount: findings.length,
        bySeverity: SEVERITIES.map((sev) => findings.filter((f) => f.severity === sev).length),
        praise: r.praise ?? [],
      };
    });
  }),
);

const returned = specialists.filter(Boolean);
const M = returned.length;
if (M === 0) return { error: "no specialist returned a review" };

await Promise.all(verifierRuns);

const isConsensus = (e) => e.count > M / 2 && e.count >= 3;

const entryRow = (e, severity) => ({
  location: findingLabel(e.finding),
  category: e.finding.category,
  severity,
  suggestion: e.finding.suggestion,
  count: e.count,
  specialists: e.specialists,
});

const consensus = [];
const corroborated = [];
const singleSource = [];
const rejected = [];
const unverified = [];

for (const e of registry) {
  if (isConsensus(e)) {
    consensus.push(entryRow(e, mostSevere(e.severities)));
    continue;
  }
  if (e.verdict && e.verdict.verdict === "invalid") {
    rejected.push({ ...entryRow(e, null), rationale: e.verdict.rationale });
    continue;
  }
  const severity = e.verdict ? e.verdict.verdict : mostSevere(e.severities);
  const row = entryRow(e, severity);
  if (!e.verdict && !e.skipVerify) {
    unverified.push(row);
  } else if (e.count >= 2) {
    corroborated.push(row);
  } else {
    singleSource.push(row);
  }
}

const bySeverityOrder = (rows) =>
  rows.sort(
    (a, b) => SEVERITIES.indexOf(a.severity) - SEVERITIES.indexOf(b.severity) || b.count - a.count,
  );

log(
  "Done: " +
    consensus.length +
    " consensus, " +
    corroborated.length +
    " corroborated, " +
    singleSource.length +
    " single-source, " +
    rejected.length +
    " rejected" +
    (unverified.length ? ", " + unverified.length + " unverified" : ""),
);

return {
  rosterSize: M,
  specialists: returned,
  consensus: bySeverityOrder(consensus),
  corroborated: bySeverityOrder(corroborated),
  singleSource: bySeverityOrder(singleSource),
  rejected,
  unverified: bySeverityOrder(unverified),
  stats: {
    findings: registry.length,
    verified: registry.filter((e) => e.verdict).length,
    rejected: rejected.length,
  },
};
