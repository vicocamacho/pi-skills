---
name: architecture-review
description: Run the deterministic fresh-context architecture reviewer, validate its findings, fix accepted blockers, and rerun the affected scope.
disable-model-invocation: true
---

# Architecture review

Run exactly one `architecture-reviewer` against a stable proposed PR scope. The child is read-only; the parent owns scope, finding disposition, and all edits.

1. Read `../pre-submit-review/SKILL.md` completely.
2. Follow its **Resolve one stable scope** procedure without alteration.
3. List executable subagents and require `architecture-reviewer`. Unavailability is a blocker; do not substitute a generic reviewer.
4. Launch exactly one fresh-context child through one asynchronous `workflowScript`. Pass the complete review packet through `args.reviewPacket`, use the absolute worktree as `cwd`, set `mission: false`, and ask the child only to apply its built-in architecture runbook to that packet without editing.
5. Do not edit while the child runs. Let native async completion wake the parent.
6. Follow **Validate and disposition findings** from the pre-submit skill for the architecture report. Verify every ownership claim, caller, comparison, and consequence directly.
7. Fix accepted `BLOCKING` findings as the only writer. Stop for a valid `DISCUSSION` finding. Do not expand a `SUGGESTION` into an unrequested refactor.
8. Resolve a new packet after any fix. Rerun the architecture reviewer when production code moved, was extracted or renamed, gained a public operation, changed ownership, or changed dependency direction. Also run the correctness and test reviewers when the architectural fix changes behavior.
9. Allow at most three architecture passes. Unresolved accepted blockers stop submission.

Report the reviewed HEAD and working-tree state, verdict, accepted fixes, rejected findings with reasons, deferred suggestions, pass count, and final gate result.
