---
name: reliable-operations
description: Design or change jobs, webhooks, callbacks, retries, duplicate delivery handling, lifecycle commands, locks, counters, schedulers, or concurrent writes. Use when an operation may run twice, resume after failure, or share mutable state.
---

# Reliable operations

For every state-changing operation, answer:

1. What happens if it runs twice?
2. What happens if it stops after each intermediate write?
3. What happens if another actor runs concurrently?

Prefer operations that converge on the intended state. Use database constraints, transactions, durable idempotency keys, and atomic updates where their guarantees match the risk.

Before adding a lock, ask whether each actor can own separate state. Eliminate shared writes when possible. When one shared writer is a real requirement, enforce it structurally rather than through comments or timing assumptions.

Test duplicate delivery, partial prior state, retry after failure, and the relevant concurrent case. Do not rely on UUID order, process-local memory, or check-then-write logic for correctness.
