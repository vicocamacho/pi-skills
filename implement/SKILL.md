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
4. State the observable outcome and name the authoritative data shape before choosing the implementation.
5. Reproduce reported defects when feasible. If reproduction is not feasible, record the evidence and uncertainty.

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
5. Run the relevant focused checks, then every repository-required validation before delivery.
6. Inspect the final diff and exercise the real feature or failure path when the environment permits it.
7. When delivery includes creating or updating a PR, read [Pre-submit review](../pre-submit-review/SKILL.md) and run its complete gate: four parallel specialists, resolve findings, then a fresh adversarial review. It owns comment review too; do not launch a separate [No comments](../no-comments/SKILL.md) pass or generic reviewer. For an implementation without PR delivery, read No comments and run its standalone comment-reviewer pass. After review fixes, rerun affected validation and follow the gate's review-rerun rules before delivery.
8. Follow the supplied delivery requirements, including PR submission and live testing. For PR delivery, any repository-file change during final validation or PR preparation requires the pre-submit gate's affected specialist reruns and a new final adversarial pass before pushing. [Challenge review](../challenge-review/SKILL.md) separately adjudicates feedback on an existing PR when requested; it does not satisfy the pre-PR gate.

## Report

Every final report must include:

- The implemented behavior.
- Validation commands and results.
- The pull-request and live-test details when required by the task.
- Residual risks or unverified behavior.
- A `Principles used` section.

Under `Principles used`, name only principles that changed the work and state the specific choice each one affected. Include applicable baseline principles as well as selected leaf principles. If no specialized principle matched, say so and still report the baseline principles that shaped the implementation.
