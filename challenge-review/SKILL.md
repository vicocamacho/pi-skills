---
name: challenge-review
description: >
  Adjudicate existing human or bot review feedback on an already-open PR.
  Challenge each finding against the actual code and concrete repo reality,
  fix only when the challenge stands (red-first), and post an evidence-grounded
  rebuttal when it doesn't. This is not a pre-PR implementation review.
  Use when the user says "challenge each comment", "run the exercise on the
  PR", "rebut or fix review feedback", or "triage the PR discussions".
---

# Challenge review: adjudicate existing PR feedback

## Purpose and lifecycle

Use this skill after a PR exists and has human or bot review feedback to
adjudicate. Its input is existing review comments; its output is a supported
fix or an evidence-backed rebuttal with a reply on the PR.

[Pre-submit review](../pre-submit-review/SKILL.md) has a different purpose:
its specialists and final adversarial reviewer examine the proposed code to
discover defects before submission. This skill challenges review claims, not
the implementation as a whole. Do not invoke it as that pre-PR gate or count
it as satisfying one.
Handoff does not automatically run this skill after submission; invoke it
when PR feedback adjudication is requested.

Review comments — especially from bots — are claims, not verdicts. Every
finding gets an independent adjudication against the real code before any
edit. The deliverable per comment is one of two things: a fix with red-first
proof and a reply naming the commit, or a rebuttal explaining why the code is
the way it is. Never silently fix, never silently ignore.

## Step 1: Collect the open findings

```bash
gh api repos/<owner>/<repo>/pulls/<N>/comments --paginate
```

Keep a running set of already-adjudicated comment IDs (including your own
replies) across rounds; each round only processes IDs not in the set. Also
check `gh pr view <N> --json comments,reviews` for top-level review bodies.
Reviewer bots re-review after every push — expect multiple rounds, and
expect later rounds to target the fixes themselves. The exercise ends when a
round produces no new actionable finding.

## Step 2: Adjudicate each finding against the code, not the prose

Read the actual code paths the comment names before forming a verdict.
Verify the claimed mechanism line by line: does the race window exist, is
the lock order really inverted, does the query really scan? A finding can be
correct in mechanism but wrong in severity, or plausible in prose but
impossible in the code. Three verdicts:

- **VALID** — mechanism confirmed, consequence matters. Fix it.
- **VALID, NARROWED** — mechanism confirmed but the real window or blast
  radius is smaller/different than claimed. Fix it, and state the precise
  boundary in the reply; honest narrowing builds credibility for rebuttals.
- **REBUT** — mechanism doesn't hold, the rule cited doesn't apply, or the
  "fix" would make the system worse. Reply with the concrete reasoning.

### The realism gate (apply before building anything)

Do not work in the abstract about potential scenarios. For each claimed
failure, answer concretely:

- **Has this class of failure happened in this repo?** Check git history,
  existing defensive patterns, field-guide docs, and owner review
  instructions. A hazard the team already built a house pattern for is real
  by precedent; copy the pattern instead of inventing one.
- **What is the actual window?** Milliseconds between two statements, or a
  minutes-long index build during daily deploys? Multiply by real event
  frequency (deploy cadence, webhook bursts, job schedules).
- **What is the consequence and the recovery?** Distinguish transient noise
  that existing retries heal (weak justification) from silent permanent
  money/data loss with no re-enqueue path (strong justification) from a
  blocked deploy train needing manual prod surgery (strong justification).
- **What does the fix cost?** An existing in-repo pattern is near-free.
  Novel machinery (circuit breakers, dry-runs, new statuses) needs a current
  concrete requirement, not a hypothetical.

A finding whose trigger is routine (gateway blips, deploy SIGTERMs,
in-flight settlement states) is not an edge case — challenge severity
framing in both directions.

### Rebuttal discipline

A rebuttal must explain why the code is the way it is, grounded in specifics:
which per-record controls already bound the blast radius, which path is
identical to the primary flow, what the proposed control would break (e.g. a
global circuit breaker stranding unrelated customer refunds). Invite a
concrete counter-scenario. A good rebuttal gets findings withdrawn; a vague
one restarts the argument.

## Step 3: Fix only with red-first proof

For every VALID finding:

1. Write the regression first and watch it fail with the exact predicted
   failure mode. If the fix is already applied (or the test pins an existing
   guard), temporarily revert/neuter the guarded code, run the test red,
   restore, and verify the restore by hash.
2. Make the smallest coherent fix, preferring the repo's established pattern
   for that problem class.
3. Run the focused suite, then every repo-required check against the final
   content. An existing test failing against your fix is signal that it pins
   a contract you missed — adjust the fix, never the pinned assertion.

Concurrency-test traps learned the hard way:

- Probing row locks from inside a SQL-notification subscriber via
  `with_connection` on the same thread returns the connection that *holds*
  the locks — `FOR UPDATE NOWAIT` trivially succeeds and the probe lies.
  Probe from a separate `Thread` (its own connection).
- Assertions inside `define_singleton_method` stubs rebind `self` and raise
  `NoMethodError` that rescue-paths may swallow silently; capture values in
  closure variables and assert after.
- Simulate a hard worker kill with a non-`StandardError` exception class so
  `rescue StandardError` recovery paths are genuinely bypassed.

## Step 4: Commit, push, reply

- Present-tense commit referencing the ticket; push (never force unless a
  requested rebase rewrote the head — then `--force-with-lease`).
- Reply on each thread (`gh api .../pulls/<N>/comments/<id>/replies`) with
  the verdict: "Challenge stands — fixed in <sha>" plus the mechanism, the
  red-first evidence, and any narrowing; or the rebuttal. Write the reply
  body to a temp file and POST with `--input`; don't shell-interpolate.
- Then re-run Step 1: the push usually triggers a new review round.

## Hard rules

- Never push with failing or unverified required checks.
- Never weaken an existing assertion to make a fix pass.
- Severity-honest replies: concede what's real (even when self-healing),
  narrow what's overstated, and say plainly when a finding is withdrawn-
  worthy. Credibility is the currency that makes rebuttals stick.
