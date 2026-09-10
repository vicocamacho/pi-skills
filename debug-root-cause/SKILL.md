---
name: debug-root-cause
description: Debug bugs, regressions, crashes, corrupt or stale state, and inconsistent behavior. Use when investigating a failure before proposing or applying a fix.
---

# Debug root causes

1. Capture the observed behavior, expected behavior, and available evidence.
2. Reproduce the failure when feasible. If it cannot be reproduced, say what evidence supports the diagnosis and what remains uncertain.
3. Trace the failure to the earliest violated assumption or invariant. Instrument and inspect actual values instead of guessing.
4. Distinguish containment from correction. During an incident, contain harm first. Do not present containment as the root-cause fix.
5. Search for other instances of the same faulty assumption when the pattern could recur.
6. Add regression coverage through the lowest stable interface that proves the corrected behavior.
7. Verify the actual failure path after the change.

Do not add a guard merely to silence an exception unless missing data is valid domain behavior or containment is the explicit goal.
