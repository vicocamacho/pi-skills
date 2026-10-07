---
name: pre-submit-review
description: Find defects before submitting a PR. Run four parallel specialist reviews, resolve findings, then require a fresh adversarial review of the integrated result. Not existing-PR feedback adjudication.
---

# Pre-submit review

One entry point owns the complete pre-PR review gate. The parent resolves scope, adjudicates findings, and remains the only writer.

```text
Implement → four parallel specialists → resolve findings → adversarial review → final validation → submit PR
```

The specialists review architecture, correctness, behavioral tests, and source comments. The final adversarial reviewer tries to disprove the requested end-to-end outcome through concrete counterexamples and interactions between changed components.

This gate is mandatory for handoff implementations and whenever the caller requires pre-submit review. Loading it authorizes its read-only reviewer launches, not publication. Do not add a separate generic reviewer or duplicate comment pass. `challenge-review` instead adjudicates human or bot feedback on an already-open PR; it does not satisfy this gate and is not automatically invoked afterward.

## Required reviewers

Load the pi-subagents skill before orchestration. List agents with `subagent({ action: "list", capabilities: true })` and require all five executable canonical agents or their listed aliases:

| Stage | Key | Agent |
| --- | --- | --- |
| Parallel specialists | `comments` | `comment-reviewer` |
| Parallel specialists | `architecture` | `architecture-reviewer` |
| Parallel specialists | `correctness` | `correctness-reviewer` |
| Parallel specialists | `tests` | `test-reviewer` |
| Final adversarial | `adversarial` | `adversarial-reviewer` |

A missing, disabled, restricted, or failed reviewer is an infrastructure blocker. Stop and report the exact failure and run/worktree state. Do not silently substitute a generic reviewer, external CLI, or parent-only review.

## Cross-provider adversarial model

The final adversarial reviewer must use the opposite model family from the primary agent: OpenAI primary → Anthropic reviewer; Anthropic primary → OpenAI reviewer. The four specialists keep their existing model settings.

Use Pi's native `subagents.agentOverridesByProvider` settings for `adversarial-reviewer`, not routing code or a model pin in its agent file. The user settings at `~/.pi/agent/settings.json` own the exact model IDs. The configured parent-provider keys cover `openai` and `openai-codex` for OpenAI, and `anthropic` and `pi-claude-cli` for Anthropic. Project settings and per-run overrides can supersede user settings, so verify the effective mapping rather than assuming it.

Before every adversarial pass, call `subagent({ action: "models", agent: "adversarial-reviewer" })`. Use its live current-session model and resolved reviewer model, not startup environment variables or the saved default. Verify that the reviewer is from the opposite family. Use `subagent({ action: "models" })` to verify its exact provider/id against the available registry when that catalog has not yet been checked or has changed. Leave the workflow's model unset so the native provider-scoped override applies; do not bypass the rule with an inherited or same-family per-run override.

An unknown primary family, absent counterpart, same-family mapping, authentication failure, or model-policy restriction blocks the adversarial stage. Report it and ask for an explicit routing decision or configuration repair; never silently inherit the primary model or switch execution modes. After completion, verify the actual child model from its run evidence and record both primary and adversarial provider/model IDs in the gate report and handoff state.

## Resolve one stable scope

Run these steps before launching any review pass:

1. Resolve the absolute worktree with `git rev-parse --show-toplevel` and use it as `cwd` for the workflow and every child.
2. Record the current branch and exact `HEAD` commit.
3. If the branch has a PR, obtain its base branch with `gh pr view --json baseRefName`. Otherwise use the caller-supplied base, falling back to `staging`.
4. Resolve the base ref deterministically. Prefer `refs/remotes/origin/<base>` when it exists; otherwise require a local `<base>` ref. Compute the merge base with `git merge-base <resolved-base-ref> HEAD`.
5. Record `git status --short`.
6. Record all tracked changed paths from the merge base through the current working tree with `git diff --name-only --find-renames <merge-base>`.
7. Fingerprint the exact tracked content with `git diff --binary --find-renames <merge-base> | shasum -a 256`.
8. Record untracked paths with `git ls-files --others --exclude-standard`. Record each untracked file's SHA-256 with `shasum -a 256 -- <path>`. If a path cannot be hashed as a regular file, record its type and target deterministically or stop as blocked.
9. Read the task, selected Linear issue or PR description, and current diff. Write a concise feature intent containing the actor, trigger, expected observable result, acceptance criteria, material constraints, and authoritative contract references. Do not invent missing product behavior. Do not include the implementer's defense or earlier review verdicts.
10. If there are no tracked or untracked changes, report that there is no review scope and stop.

The review packet must contain:

```text
WORKTREE: <absolute path>
BRANCH: <branch>
BASE BRANCH: <base>
BASE REF: <resolved ref>
MERGE BASE: <commit>
EXPECTED HEAD: <commit>
STATUS:
<exact git status --short output>
TRACKED CHANGED PATHS:
<paths>
TRACKED DIFF SHA256: <sha256>
UNTRACKED PATHS AND SHA256:
<sha256 and path, or none>
FEATURE INTENT:
<actor, trigger, observable result, acceptance criteria, constraints, contract references>
```

Freeze the candidate until every reviewer in the pass completes. Do not edit, stage, commit, or run commands that change reviewed content or Git state. Validation may run concurrently only when it cannot alter the snapshot or a shared resource reviewers inspect. Finish or stop checks reading the candidate before applying fixes. If content changes during a pass, discard that pass as stale and resolve a new packet.

## Launch one review pass

Each frozen pass uses one top-level asynchronous workflow; all its children launch inside it. Finish and adjudicate that pass before starting another. Use fresh context, no managed worktrees, and no mission. Bind reviewer reports to tool-managed artifact paths outside the repository.

Select `comments`, `architecture`, `correctness`, and `tests` for the initial specialist pass. After resolving their findings and any required specialist reruns, select only `adversarial` for the final pass. Never launch the adversarial reviewer alongside specialists or before their findings are resolved.

Use this workflow shape, written as one `js workflow` block in the same reply as `subagent({ workflow: true, ... })`:

```javascript
const selected = args.reviewers;
const lanes = [
  { key: "comments", label: "Review source comments", agent: "comment-reviewer" },
  { key: "architecture", label: "Review architectural ownership", agent: "architecture-reviewer" },
  { key: "correctness", label: "Review behavior correctness", agent: "correctness-reviewer" },
  { key: "tests", label: "Review behavioral tests", agent: "test-reviewer" },
  { key: "adversarial", label: "Challenge integrated outcomes", agent: "adversarial-reviewer" }
];
if (!Array.isArray(selected) || selected.length === 0 ||
    new Set(selected).size !== selected.length ||
    selected.some(key => !lanes.some(lane => lane.key === key)) ||
    (selected.includes("adversarial") && selected.length !== 1)) {
  throw new Error("Select specialist reviewers or the final adversarial reviewer, not both.");
}
if (!Number.isSafeInteger(args.pass) || args.pass < 1 ||
    typeof args.reviewPacket !== "string" || !args.reviewPacket.trim()) {
  throw new Error("A positive pass number and a complete review packet are required.");
}
const results = await runs.all(lanes.filter(lane => selected.includes(lane.key)).map(lane => ({
  key: "pass-" + args.pass + "-" + lane.key,
  label: lane.label,
  agent: lane.agent,
  task: "Apply your built-in runbook to this exact proposed PR scope. Do not edit.\n\n" + args.reviewPacket,
  context: "fresh",
  worktree: false,
  output: "reviews/pass-" + args.pass + "-" + lane.key + ".md"
})));
return results.map(result => ({
  ok: result.ok,
  runId: result.runId,
  output: result.output,
  outputReference: result.outputReference,
  outputPathMapping: result.outputPathMapping,
  artifactPaths: result.artifactPaths
}));
```

Call it with `async: true`, `context: "fresh"`, `cwd: <absolute worktree>`, `mission: false`, `artifacts: true`, and `args: { reviewPacket: <packet>, reviewers: <selected keys>, pass: <unique pass number> }`. Keep the packet within the tool's argument limits; do not omit scope evidence to make it fit. If necessary, store the complete packet outside the repository and pass its absolute path with an instruction to read it instead of embedding it in `args`.

In an interactive session, yield when no safe independent work remains. Let native completion wake the parent; do not poll or call `bg_wait` merely to wait.

## Validate and disposition findings

After every selected reviewer completes:

1. Recheck `HEAD`, status, tracked changed paths, tracked diff SHA-256, untracked paths, and every untracked SHA-256 against the packet. A mismatch invalidates the pass.
2. Read every report and verify its scope. A failed child, `REVIEW BLOCKED`, malformed report, missing output, or missing evidence blocks submission. A launch receipt is not a completed review.
3. Deduplicate findings about the same mechanism across reports, preserving each source and any distinct consequence. Verify cited paths, symbols, callers, contracts, and repository patterns directly.
4. Classify each finding as:
   - `accepted blocker`: supported by current source and within the PR scope;
   - `accepted suggestion`: supported but not required for this PR;
   - `discussion`: requires product or architecture authority not present in source;
   - `stale`: absent from the reviewed state;
   - `invalid`: contradicted by source, contract, or repository instructions;
   - `out of scope`: real but not introduced or made materially reachable by this diff;
   - `speculative`: lacks a reachable scenario, contract contradiction, or ownership consequence.
5. Record a concise reason for rejected, stale, out-of-scope, and speculative findings. Reviewer output is evidence, not authority. No actionable findings is a valid result; impose no finding quota.
6. Accepted comment `DELETE` and `MUST KILL` findings and any accepted `BLOCKING` finding prevent submission. A valid `DISCUSSION` finding requires the user's decision. Suggestions do not block; apply only task-scoped, low-risk suggestions that add no unrequested abstraction or behavior.
7. The parent applies accepted fixes together only after the pass and concurrent readers finish. For behavior defects, reproduce with a red-first regression when feasible. Otherwise record the evidence and why automated reproduction is not reliable before editing. Never weaken an existing assertion to make a fix pass.

For comment dispositions, follow `../no-comments/SKILL.md` starting after its launch step, including constraint-encoding approval rules. Do not launch another comment reviewer for an unchanged candidate.

## Rerun rules

After any repository-file change, resolve a new packet. Compare the change since each retained report, including its relevant callers, dependencies, contracts, and test setup. Rerun affected specialists in parallel:

| Change affects | Required specialist reruns |
| --- | --- |
| Comments, suppressions, or code changes justified by them | Comments; also the specialists affected by any code-shape fix |
| Ownership, boundaries, dependencies, or public operations | Architecture; correctness and tests when behavior or a contract changes |
| Observable behavior, authorization, persistence, queries, ordering, failures, or external contracts | Correctness and tests; architecture when ownership or dependencies change |
| Tests, assertions, fixtures, helpers, or shared test setup | Tests; correctness when a test exposes or changes the intended contract |
| Cross-cutting instructions, schema, configuration, dependencies, or uncertain impact | All four specialists |

A previous specialist result may be retained only with a recorded explanation and source evidence that its reviewed concern and relevant dependencies are unchanged. Keep its original packet and report; never relabel an old report as a review of a new fingerprint. If unaffectedness cannot be established, rerun all four. A stale in-flight pass cannot be rescued by this rule.

Once specialists have no unresolved blockers or discussions, run a fresh adversarial pass against the current complete candidate. Any later repository-file change invalidates that adversarial pass. Resolve findings, rerun affected specialists, then rerun the fresh adversarial reviewer over the complete corrected result. Apply the same rule to fixes made during final validation or PR preparation before pushing. Do not launch a sixth generic reviewer or invoke `challenge-review`.

Metadata-only operations such as committing unchanged content, renaming a branch, or editing Linear/PR metadata do not invalidate review evidence. Re-resolve the packet and verify equivalent candidate content and unchanged base/feature intent before retaining it. If the merge base, requirements, or contracts change, rerun all five in stage order.

Allow at most three specialist passes and three adversarial passes per gate invocation. Use new pass numbers and workflow keys for each launch. If the third pass in either stage requires another review, stop and report the unresolved work without pushing or submitting. Do not reset counters to bypass the limit. Infrastructure failures remain blockers, not passing or skipped reviews.

## Passing condition

The gate passes only when:

- all four specialists completed, with current evidence or documented unaffected-result reuse;
- the final fresh adversarial reviewer completed against the exact current candidate after specialist findings were resolved, using the opposite model family from the primary agent;
- no report is failed, blocked, malformed, or missing;
- no accepted `DELETE`, `MUST KILL`, `BLOCKING`, or `DISCUSSION` finding remains;
- all fixes are covered by the required specialist and adversarial reruns;
- the parent verified that the final candidate still matches the adversarial packet or a proven content-equivalent metadata-only successor.

Report each reviewer's verdict and report reference, accepted fixes, rejected findings with reasons, deferred suggestions, retained-result evidence, stage pass counts, primary and adversarial provider/model IDs, final fingerprints, and whether the gate passed. In a handoff, record this in the excluded `HANDOFF-STATE.md` at the phase boundary. Do not claim CI passed from review evidence; required final validation is a separate gate and must pass for the final content before submission.
