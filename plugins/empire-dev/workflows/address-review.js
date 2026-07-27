export const meta = {
  name: "address-review",
  description:
    "Address PR review comments for /empire-dev:address-review — adversarial verification per comment, fix-approach evaluation, recheck of alternatives, parallel implementation grouped by file, direct-tone reply drafts.",
  whenToUse:
    "Invoked by /empire-dev:address-review when the Workflow tool is available. Requires args {pr, comments:[{id, path, line, body, author, diffHunk, discussion}]}. Edits files in the working tree; never commits, pushes, or posts to GitHub.",
  phases: [
    { title: "Verify", detail: "adversarial check per comment" },
    { title: "Evaluate", detail: "best fix per valid comment" },
    { title: "Recheck", detail: "adversarial check of alternative fixes" },
    { title: "Fix", detail: "parallel implementation grouped by file" },
  ],
};

const VERDICT_SCHEMA = {
  type: "object",
  required: ["valid", "rationale"],
  properties: {
    valid: { type: "boolean" },
    rationale: { type: "string" },
    pushbackReply: { type: "string" },
  },
};

const EVAL_SCHEMA = {
  type: "object",
  required: ["approach", "plan", "files", "rationale"],
  properties: {
    approach: { type: "string", enum: ["proposed", "alternative"] },
    plan: { type: "string" },
    files: { type: "array", items: { type: "string" } },
    rationale: { type: "string" },
  },
};

const RECHECK_SCHEMA = {
  type: "object",
  required: ["holds", "rationale"],
  properties: {
    holds: { type: "boolean" },
    rationale: { type: "string" },
  },
};

const FIX_SCHEMA = {
  type: "object",
  required: ["fixes", "filesChanged"],
  properties: {
    fixes: {
      type: "array",
      items: {
        type: "object",
        required: ["commentId", "done", "summary", "reply"],
        properties: {
          commentId: { type: "number" },
          done: { type: "boolean" },
          summary: { type: "string" },
          reply: { type: "string" },
        },
      },
    },
    filesChanged: { type: "array", items: { type: "string" } },
  },
};

const REPLY_RULES =
  "Reply rules: 1 or 2 short sentences maximum. Direct tone. " +
  "No dashes of any kind. No semicolons. No trivia, no thanks, no filler. " +
  "State the outcome and nothing else.";

const pr = args?.pr ?? "";
const comments = args?.comments ?? [];

if (!pr || comments.length === 0) {
  return { error: "address-review requires args {pr, comments:[{id, path, line, body}]}." };
}

const label = (c) => c.path + ":" + (c.line ?? "?");

const COMMENT_BLOCK = (c) =>
  "## Review comment\n" +
  "- PR: #" +
  pr +
  " (branch checked out in the current working directory)\n" +
  "- Location: `" +
  label(c) +
  "`\n" +
  "- Author: " +
  (c.author || "unknown") +
  "\n- Comment:\n" +
  c.body +
  "\n" +
  (c.diffHunk ? "\n## Diff hunk\n```\n" + c.diffHunk + "\n```\n" : "") +
  (c.discussion ? "\n## Thread discussion\n" + c.discussion + "\n" : "");

const VERIFY_PROMPT = (c) =>
  "## Adversarial reviewer-of-the-reviewer\n\n" +
  "Try to REFUTE this PR review comment. Read the actual file and surrounding code; " +
  "run `gh pr diff " +
  pr +
  "` if you need the full diff. " +
  "The comment is invalid if the issue does not exist in the current code, is already handled, " +
  "rests on a wrong assumption, or asks for something outside the PR's scope.\n\n" +
  COMMENT_BLOCK(c) +
  "\n## Task\n" +
  "- valid=true only if the issue genuinely holds against the current code.\n" +
  "- rationale: one sentence.\n" +
  "- If invalid, write pushbackReply telling the reviewer why no change is made. " +
  REPLY_RULES +
  "\n- Do NOT edit files. Do NOT post to GitHub. Structured output only.";

const EVAL_PROMPT = (c) =>
  "## Fix strategist\n\n" +
  "This review comment was verified as valid. Decide the BEST way to fix it: " +
  "the reviewer's proposed change as written, or a better alternative. " +
  "Prefer the reviewer's proposal unless an alternative is clearly better on correctness, " +
  "simplicity, or consistency with the surrounding code. Read the code first.\n\n" +
  COMMENT_BLOCK(c) +
  "\n## Task\n" +
  "- approach: 'proposed' or 'alternative'.\n" +
  "- plan: concrete edit steps, minimal diff, no drive-by refactors.\n" +
  "- files: every file the plan touches.\n" +
  "- rationale: one sentence.\n" +
  "- Do NOT edit files. Do NOT post to GitHub. Structured output only.";

const RECHECK_PROMPT = (c, plan) =>
  "## Adversarial plan checker\n\n" +
  "A strategist replaced the reviewer's proposed change with an alternative fix. " +
  "Try to REFUTE the alternative: does it fully address the comment, does it break " +
  "anything the proposal would not, is it genuinely better than the proposal? " +
  "Default to holds=false when uncertain.\n\n" +
  COMMENT_BLOCK(c) +
  "\n## Alternative plan\n" +
  plan.plan +
  "\n\nStrategist rationale: " +
  plan.rationale +
  "\n\n## Task\n" +
  "- holds=true only if the alternative survives scrutiny.\n" +
  "- rationale: one sentence.\n" +
  "- Do NOT edit files. Do NOT post to GitHub. Structured output only.";

const FIX_PROMPT = (group) =>
  "## Fix implementer\n\n" +
  "Implement the following verified review fixes in the current working tree (PR #" +
  pr +
  " branch is checked out). Every changed line MUST trace to a fix plan below. " +
  "No drive-by refactors. Do NOT commit, push, or post to GitHub.\n\n" +
  group.items
    .map(
      (r, i) =>
        "### Fix " +
        (i + 1) +
        " (commentId " +
        r.comment.id +
        ", `" +
        label(r.comment) +
        "`)\n" +
        "Comment:\n" +
        r.comment.body +
        "\n\nPlan (" +
        r.plan.approach +
        "):\n" +
        r.plan.plan,
    )
    .join("\n\n") +
  "\n\n## Task\n" +
  "- Apply each plan with minimal edits; verify the result reads correctly in context.\n" +
  "- Per fix return: commentId, done (false if you could not apply it), one-line summary, " +
  "and reply (the text to post back to the reviewer). " +
  REPLY_RULES +
  "\n- filesChanged: every file you edited.\n- Structured output only.";

log("Verifying " + comments.length + " review comments");

const perComment = await pipeline(
  comments,
  (c) =>
    agent(VERIFY_PROMPT(c), {
      label: "verify:" + label(c),
      phase: "Verify",
      schema: VERDICT_SCHEMA,
    }).then((v) => (v ? { comment: c, verdict: v } : null)),
  (r) => {
    if (!r) return null;
    if (!r.verdict.valid) {
      log(label(r.comment) + ": invalid, drafting pushback");
      return { ...r, action: "pushback" };
    }
    return agent(EVAL_PROMPT(r.comment), {
      label: "evaluate:" + label(r.comment),
      phase: "Evaluate",
      schema: EVAL_SCHEMA,
    }).then((e) => (e ? { ...r, plan: e } : { ...r, action: "failed" }));
  },
  (r) => {
    if (!r || r.action || r.plan.approach !== "alternative") return r;
    return agent(RECHECK_PROMPT(r.comment, r.plan), {
      label: "recheck:" + label(r.comment),
      phase: "Recheck",
      schema: RECHECK_SCHEMA,
    }).then((k) => {
      if (k && k.holds) return r;
      log(label(r.comment) + ": alternative refuted, reverting to proposed change");
      return {
        ...r,
        plan: {
          approach: "proposed",
          plan: "Apply the reviewer's proposed change as written in the comment.",
          files: r.plan.files,
          rationale: k ? k.rationale : "recheck unavailable, defaulting to proposed",
        },
      };
    });
  },
);

const settled = perComment.filter(Boolean);
const fixable = settled.filter((r) => !r.action && r.plan);

const groups = [];
for (const r of fixable) {
  const files = new Set([r.comment.path, ...(r.plan.files || [])]);
  const overlapping = groups.filter((g) => [...files].some((f) => g.files.has(f)));
  let target = overlapping[0];
  if (!target) {
    target = { files: new Set(), items: [] };
    groups.push(target);
  }
  for (const g of overlapping.slice(1)) {
    g.files.forEach((f) => target.files.add(f));
    target.items.push(...g.items);
    groups.splice(groups.indexOf(g), 1);
  }
  files.forEach((f) => target.files.add(f));
  target.items.push(r);
}

phase("Fix");
log("Fixing " + fixable.length + " comments in " + groups.length + " parallel groups");

const fixOutputs = await parallel(
  groups.map(
    (g) => () =>
      agent(FIX_PROMPT(g), {
        label: "fix:" + [...g.files][0],
        phase: "Fix",
        schema: FIX_SCHEMA,
      }).then((out) => ({ group: g, out })),
  ),
);

const fixByComment = new Map();
for (const entry of fixOutputs.filter(Boolean)) {
  const { group, out } = entry;
  if (!out) {
    group.items.forEach((r) => fixByComment.set(r.comment.id, null));
    continue;
  }
  for (const f of out.fixes)
    fixByComment.set(f.commentId, { ...f, filesChanged: out.filesChanged });
}

const results = settled.map((r) => {
  const base = {
    commentId: r.comment.id,
    path: r.comment.path,
    line: r.comment.line ?? null,
    rationale: r.verdict.rationale,
  };
  if (r.action === "pushback") {
    return { ...base, action: "pushback", reply: r.verdict.pushbackReply || "" };
  }
  if (r.action === "failed") return { ...base, action: "failed", reply: "" };
  const fix = fixByComment.get(r.comment.id);
  if (!fix || !fix.done) return { ...base, action: "failed", reply: "" };
  return {
    ...base,
    action: "fixed",
    approach: r.plan.approach,
    summary: fix.summary,
    reply: fix.reply,
    files: fix.filesChanged,
  };
});

const count = (a) => results.filter((r) => r.action === a).length;
log(
  "Done: " +
    count("fixed") +
    " fixed, " +
    count("pushback") +
    " pushback, " +
    count("failed") +
    " failed",
);

return {
  pr,
  results,
  stats: {
    total: comments.length,
    fixed: count("fixed"),
    pushback: count("pushback"),
    failed: count("failed") + (comments.length - settled.length),
  },
};
