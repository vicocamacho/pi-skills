---
name: pre-submit-review
description: Run the required fresh-context comment, architecture, correctness, and test review gates before submitting a pull request.
disable-model-invocation: true
---

# Pre-submit review

Run four independent, read-only reviewers against one stable proposed PR scope. The parent resolves scope, launches the reviewers, validates findings, and remains the only writer.

This is a required pre-submit gate when a caller explicitly loads this skill. Do not replace it with a general code review or a self-review by the implementation agent.

## Required reviewers

Before execution, list executable subagents and require all four canonical agents or their listed aliases:

- `comment-reviewer`
- `architecture-reviewer`
- `correctness-reviewer`
- `test-reviewer`

A missing, disabled, restricted, or failed reviewer is an infrastructure blocker. Stop and report it. Do not silently use a generic reviewer, an external CLI, or a parent-only fallback.

## Resolve one stable scope

Run these steps before launching any reviewer:

1. Resolve the absolute worktree with `git rev-parse --show-toplevel` and use it as `cwd` for the workflow and every child.
2. Record the current branch and exact `HEAD` commit.
3. If the branch has a PR, obtain its base branch with `gh pr view --json baseRefName`. Otherwise use the caller-supplied base, falling back to `staging`.
4. Resolve the base ref deterministically. Prefer `refs/remotes/origin/<base>` when it exists; otherwise require a local `<base>` ref. Compute the merge base with `git merge-base <resolved-base-ref> HEAD`.
5. Record `git status --short`.
6. Record all tracked changed paths from the merge base through the current working tree with `git diff --name-only --find-renames <merge-base>`.
7. Fingerprint the exact tracked content with `git diff --binary --find-renames <merge-base> | shasum -a 256`.
8. Record untracked paths with `git ls-files --others --exclude-standard`. Record each untracked file's SHA-256 with `shasum -a 256 -- <path>`. If a path cannot be hashed as a regular file, record its type and target deterministically or stop as blocked.
9. Read the task, selected Linear issue or PR description, and current diff. Write a concise feature intent containing the actor, trigger, expected observable result, and material constraints. Do not invent missing product behavior.
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
<actor, trigger, observable result, constraints>
```

Do not edit files, stage changes, commit, or run mutating commands after recording this packet until every reviewer in the pass has completed. If the worktree changes during a pass, discard that pass as stale and rerun it against a newly resolved packet.

## Launch one review pass

Use exactly one top-level asynchronous `workflowScript` for the pass. Launch the four reviewers inside it with `runs.all`. Use fresh context, no worktrees, no child output files in the repository, and no mission for this ephemeral gate. Pass the packet through raw-script `args`, not by interpolating shell output into JavaScript source.

Use this workflow shape:

```javascript
const packet = args.reviewPacket;
const results = await runs.all([
  {
    key: "comments",
    label: "Review source comments",
    agent: "comment-reviewer",
    task: "Review the exact proposed PR scope below using your built-in runbook. Do not edit.\n\n" + packet,
    context: "fresh",
    output: false
  },
  {
    key: "architecture",
    label: "Review architectural ownership",
    agent: "architecture-reviewer",
    task: "Apply your built-in architecture runbook to this exact proposed PR scope. Do not edit.\n\n" + packet,
    context: "fresh",
    output: false
  },
  {
    key: "correctness",
    label: "Review behavior correctness",
    agent: "correctness-reviewer",
    task: "Apply your built-in correctness runbook to this exact proposed PR scope. Do not edit.\n\n" + packet,
    context: "fresh",
    output: false
  },
  {
    key: "tests",
    label: "Review behavioral tests",
    agent: "test-reviewer",
    task: "Apply your built-in test runbook to this exact proposed PR scope. Do not edit.\n\n" + packet,
    context: "fresh",
    output: false
  }
]);
return {
  comments: results[0].output,
  architecture: results[1].output,
  correctness: results[2].output,
  tests: results[3].output
};
```

Call it with:

- `async: true`
- `context: "fresh"`
- `cwd: <absolute worktree>`
- `mission: false`
- `args: { reviewPacket: <packet> }`
- `artifacts: true`

In an interactive session, yield after launch when no safe independent work remains. Let native async completion wake the session. Do not poll or call `bg_wait` merely to wait.

## Validate and disposition findings

After all four reviewers complete:

1. Recheck `HEAD`, `git status --short`, tracked changed paths, the tracked diff SHA-256, and every untracked path SHA-256 against the packet. If any differ, mark the whole pass stale and rerun it.
2. Read every report. A `REVIEW BLOCKED` result, malformed report, missing output, or reviewer failure blocks submission.
3. Verify every cited path, line, symbol, caller, contract, and repository pattern directly.
4. Classify each finding as:
   - `accepted blocker`: supported by current source and within the PR scope;
   - `accepted suggestion`: supported but not required for this PR;
   - `discussion`: requires product or architecture authority not present in source;
   - `stale`: absent from the reviewed state;
   - `invalid`: contradicted by source, contract, or repository instructions;
   - `out of scope`: real but not introduced or made materially reachable by this diff;
   - `speculative`: lacks a reachable scenario, contract contradiction, or ownership consequence.
5. Record a concise reason for every rejected, stale, out-of-scope, or speculative finding. Reviewer output is evidence, not authority.
6. Apply these gate rules:
   - Accepted comment-reviewer `DELETE` findings must be removed before submission.
   - Accepted comment-reviewer `MUST KILL` findings block until the code-shape cause is fixed.
   - Accepted `BLOCKING` architecture, correctness, or test findings block submission.
   - Any valid `DISCUSSION` finding stops automation and requires the user’s decision.
   - `SUGGESTION` findings do not block. Apply one only when it is task-scoped, low-risk, and does not add a new abstraction or behavior.
7. The parent is the only writer. Apply accepted fixes only after all reports in the pass are complete.

When validating comment-reviewer findings, follow the disposition and constraint-encoding rules in `../no-comments/SKILL.md`, starting after its launch step. Do not launch a second comment reviewer for the same unchanged pass.

## Rerun rules

A review pass covers only the exact content fingerprints in its packet. Any accepted fix to a tracked or untracked file invalidates the complete pass. Resolve a new packet and rerun all four reviewers together. Do not attempt to decide that a file change affects only one review concern.

Committing unchanged content, renaming the branch, or editing Linear and PR metadata does not invalidate a passing review. Any later repository-file change made while fixing CI does invalidate it and requires another complete four-reviewer pass before push.

Use new stable workflow keys for every rerun. Never reuse a result from a different content fingerprint. Allow at most three total review passes. If accepted blockers remain after the third pass, stop and report them without committing or submitting.

## Passing condition

The gate passes only when:

- every required reviewer completed against the same current scope;
- no report is blocked or malformed;
- no accepted `DELETE`, `MUST KILL`, `BLOCKING`, or `DISCUSSION` finding remains;
- every accepted fix was covered by the required rerun;
- the parent verified the final worktree still matches the final review packet.

Report each reviewer’s verdict, accepted fixes, rejected findings with reasons, deferred suggestions, pass count, reviewed HEAD, and whether the gate passed. Do not claim CI passed; CI is a later gate.
