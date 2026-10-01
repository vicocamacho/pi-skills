---
name: test-review
description: Run the deterministic fresh-context test reviewer, validate its behavior-to-test findings, fix accepted blockers, and rerun the affected scope.
disable-model-invocation: true
---

# Test review

Run exactly one `test-reviewer` against a stable proposed PR scope. The child is read-only; the parent owns scope, finding disposition, and all edits.

1. Read `../pre-submit-review/SKILL.md` completely.
2. Follow its **Resolve one stable scope** procedure without alteration.
3. List executable subagents and require `test-reviewer`. Unavailability is a blocker; do not substitute a generic reviewer.
4. Launch exactly one fresh-context child through one asynchronous `workflowScript`. Pass the complete review packet through `args.reviewPacket`, use the absolute worktree as `cwd`, set `mission: false`, and ask the child only to apply its built-in test runbook to that packet without editing.
5. Do not edit while the child runs. Let native async completion wake the parent.
6. Follow **Validate and disposition findings** from the pre-submit skill for the test report. Verify each coverage obligation against the cited test, assertion, helper, fixture, and production path.
7. Fix accepted `BLOCKING` findings as the only writer. Stop for a valid `DISCUSSION` finding. Do not add tests for private implementation details or framework behavior.
8. Resolve a new packet after any fix. Rerun tests after test changes or behavior changes. Also rerun correctness if a test fix reveals or changes the intended contract, and architecture if production ownership changes.
9. Allow at most three test-review passes. Unresolved accepted blockers stop submission.

Report the reviewed HEAD and working-tree state, verdict, accepted fixes, rejected findings with reasons, deferred suggestions, pass count, and final gate result.
