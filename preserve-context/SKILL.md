---
name: preserve-context
description: Preserve reasoning quality and task continuity during long sessions, multi-step work, large file or command output, repeated investigation, delegation, handoffs, or approaching context limits. Use before context becomes crowded or work changes hands.
---

# Preserve context

Keep the main conversation focused on decisions, evidence, current state, and the next action.

1. Read selectively. Search first, then read the relevant files and bounded sections. Do not skip source needed for correctness merely to save tokens.
2. Avoid repeating raw output. Record the conclusion and retain the command, file path, line, URL, or artifact needed to verify it.
3. Route bounded research and large independent investigations to subagents. Require concise findings with evidence rather than full transcripts.
4. Keep authoritative constraints, unresolved questions, and current decisions visible. Summarize background that no longer affects the next decision.
5. Before compaction or handoff, record the goal, decisions, changed files, checks run, failures, residual risks, and exact next step in a durable handoff or artifact.
6. Re-read the authoritative source when precision matters. Do not treat a summary as stronger evidence than the source it summarizes.
7. Remove stale assumptions from the working summary when later evidence disproves them.

Do not write temporary context notes into the product repository unless they are requested deliverables. Context preservation supports correctness; it does not justify incomplete inspection or premature conclusions.
