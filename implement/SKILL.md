---
name: implement
description: Analyze and implement a development task through verified delivery. Use only when invoked explicitly with /skill:implement, normally by the handoff skill.
disable-model-invocation: true
---

# Implement

Own the requested change from problem analysis through verified delivery. The command arguments contain the task and may contain additional delivery requirements.

## Ownership and rollover gate

Keep ownership through implementation, review, validation, and delivery. A failed subagent, workflow timeout, expired supervisor request, blocked review, long-running test, or large tool output does not authorize transferring the task to a new primary agent.

Start a replacement primary agent only when the user explicitly requests that transfer, or when the task authorizes automatic rollover and an automatic compaction event has actually occurred. Record the observed event or explicit user instruction before creating the new agent. A context warning, estimated context pressure, stale output, phase boundary, or a feeling that the session is bloated is not a compaction event. Do not trigger compaction just to manufacture permission to transfer ownership.

Without a valid trigger, stay in this session. Summarize evidence, keep bulk output in artifacts or authorized subagents, and recover failed lanes through the governed protocol. If recovery needs approval or remains blocked, report the blocker and retain primary ownership; do not hand off unfinished delivery as a substitute for recovery.

## Resuming a rollover

When the request says to resume from `HANDOFF-STATE.md`, read that file at the worktree root first. It is the authoritative record of the task, delivery requirements, plan, decisions, progress, and next step. Confirm ownership to the outgoing agent's handover, verify the recorded state against the actual worktree (branch, diff, test status) before trusting it, then continue from the recorded next step under the same delivery requirements, including maintaining the state file and the rollover rule itself.

## Establish the task

When the request names a Linear ticket or includes a Linear issue URL:

1. Retrieve the issue from Linear, including its description and relations.
2. Read its comments. Inspect linked documents, attachments, and embedded images when they affect the requirements.
3. Treat the issue, its discussion, and explicit instructions in the request as the task. An explicit user instruction takes precedence when it narrows or overrides the ticket.
4. Verify that the current branch matches the issue's `gitBranchName` when Linear provides one. Stop and report the mismatch before making changes.

When the request has no ticket, treat the supplied description as the task. Ask a question only when missing information leaves materially different product behavior, data handling, security, or external contracts.

## Understand before editing

1. Read the applicable `AGENTS.md` files and repository instructions.
2. Read any field guide or domain documentation required by those instructions.
3. Inspect the relevant implementation, tests, callers, and recent local changes.
4. Before choosing the implementation, map each requested observable behavior to its actor and trigger, authoritative data shape, owning code, affected entry points and callers, authoritative contract, and planned behavioral assertion. Include material failure behavior. Use source paths and symbols, and compare ownership with the closest existing repository pattern. Mark unknowns rather than inventing product behavior; resolve uncertainty that changes product behavior, data handling, security, or external contracts before editing.
5. Reproduce reported defects when feasible. If reproduction is not feasible, record the evidence and uncertainty.

Keep the behavior map concise in the conversation or existing handoff state, not a new repository document. Update it as source evidence changes. It guides implementation and verification; it is not an implementer's defense to include in independent review packets.

## Select principles

The repository instructions are always authoritative. Apply their baseline principles first: protect security, data integrity, and external contracts; respect ownership boundaries; make the smallest coherent change; test observable behavior; and stop when the requested result is proven.

Select every specialized principle whose trigger matches. Read its leaf `SKILL.md` in full before planning or editing. Do not load unrelated principles.

- Reported bug, regression, crash, stale state, or inconsistent behavior. Read [Debug root causes](../debug-root-cause/SKILL.md).
- Repeated branches, synchronized values, invalid states, repeated shape assumptions, or unclear domain ownership. Read [Domain remodeling](../domain-remodeling/SKILL.md).
- Jobs, webhooks, callbacks, retries, duplicate delivery, lifecycle commands, locks, schedulers, counters, or concurrent writes. Read [Reliable operations](../reliable-operations/SKILL.md).
- Repetitive or high-risk changes across many files, records, schemas, or callers. Read [Mechanical migrations](../mechanical-migrations/SKILL.md).
- Novel UI or architectural work with no established repository pattern and materially different valid options. Read [Design exploration](../design-exploration/SKILL.md).
- Long, multi-phase, delegated, or context-heavy work. Read [Preserve context](../preserve-context/SKILL.md).

Read [Unslop](../unslop/SKILL.md) before writing user-facing prose, documentation, commit messages, pull-request text, or the final report.

A principle counts as used only when it changes a concrete decision. Do not claim a specialized principle whose leaf skill was not read during this session.

## Implement and verify

1. Plan nontrivial work in small units that each end with an observable check.
2. Use test-driven development whenever the behavior can be proven through a stable automated test. For a reported defect, first add the smallest behavior-focused test that reproduces it and run the test to confirm it fails for the expected reason. Only then change production code and rerun the test until it passes. If a reliable automated reproduction is not feasible, document why and identify the substitute evidence before editing. Do not call a test regression coverage if its first observed result was green.
3. Make the smallest coherent change that satisfies the task and repository rules.
4. Add or update any remaining behavior-focused tests through the lowest stable interface that proves the result.
5. Run the relevant focused checks, then every repository-required validation before launching review. Record commands, results, and any blocked checks; do not treat unavailable validation as passing.
6. Inspect the final diff and exercise the real feature or failure path when the environment permits it.
7. Complete the review-ready checkpoint below before launching any reviewer. When delivery includes creating or updating a PR, read [Pre-submit review](../pre-submit-review/SKILL.md) and run its complete gate: four parallel specialists, resolve findings, then a fresh adversarial review. It owns comment review too; do not launch a separate [No comments](../no-comments/SKILL.md) pass or generic reviewer. For an implementation without PR delivery, read No comments and run its standalone comment-reviewer pass. After review fixes, rerun affected validation and follow the gate's review-rerun rules before delivery.
8. Wait for every reviewer in the pass and any concurrent readers to finish, then deduplicate and verify findings against source and contracts. Apply accepted blockers together as one coherent correction before validation and required reruns. Do not edit in response to individual reports as they arrive. Defer optional polish rather than expanding the candidate after specialist approval; necessary later changes still require the gate's affected specialist reruns and a fresh adversarial pass.
9. Follow the supplied delivery requirements, including PR submission and live testing. For PR delivery, any repository-file change during final validation or PR preparation requires the pre-submit gate's affected specialist reruns and a new final adversarial pass before pushing. [Challenge review](../challenge-review/SKILL.md) separately adjudicates feedback on an existing PR when requested; it does not satisfy the pre-PR gate.

## Review-ready checkpoint

This is the implementer's evidence check, not another reviewer launch or a substitute for independent review. Reuse evidence gathered during implementation rather than repeating the whole investigation.

Before the first review pass:

1. Reconcile the behavior map with the complete candidate diff, including untracked files. Trace each changed behavior from its real entry point through decisions and side effects to persistence, delivery, or rendering. Check applicable authorization and ownership boundaries, invalid inputs, partial failures, retries, repeated requests, and ordering ties.
2. Verify each material behavior and failure contract has a specific test and assertion that would fail if it broke. Use the lowest stable interface that proves it. Where automated proof is unreliable, record the reason and substitute evidence; do not claim coverage from an exercised line or a mock interaction alone.
3. Check changed decisions against the repository's ownership boundaries and closest existing pattern. Remove duplicated authority, speculative abstractions, and pass-through wrappers with no concrete ownership, contract, or complexity benefit.
4. Inspect added or modified comments and suppressions. Remove narration and unsupported workarounds; express repository-owned constraints through code and tests where possible. Preserve required legal, public-contract, and proven non-obvious external-constraint comments.
5. Complete all intended repository edits, including applicable API documentation, translations, schema, fixtures, and delivery-required artifacts. Verify required validation results apply to this candidate; rerun affected checks after any subsequent edit. Exercise the real feature or failure path when possible and record any remaining unverified behavior.
6. Record concise source and assertion references, validation results, and unresolved questions in the conversation or existing handoff state. Resolve known blockers and material product or contract questions before review. Keep independent review intent limited to requirements and authoritative contracts, without the self-check's verdict or implementation rationale.

Freeze the candidate for review under the pre-submit gate's snapshot rules. This checkpoint does not authorize skipping reviewers, weakening validation, reusing affected reports, or exceeding the gate's pass limits.

## Report

Every final report must include:

- The implemented behavior.
- Validation commands and results.
- The pull-request and live-test details when required by the task.
- Residual risks or unverified behavior.
- A `Principles used` section.

Under `Principles used`, name only principles that changed the work and state the specific choice each one affected. Include applicable baseline principles as well as selected leaf principles. If no specialized principle matched, say so and still report the baseline principles that shaped the implementation.
