---
name: no-comments
description: "Spawn Comment Sicko, fix accepted findings, and offer encodings for claimed constraints."
license: MIT
metadata:
  source: https://github.com/cursor/plugins/blob/main/pstack/skills/no-comments/SKILL.md
disable-model-invocation: true
---

# No comments

Spawn Comment Sicko. Act on accepted findings.

Authoring agents defend comments. Defer to Comment Sicko's fresh perspective.

## Scope

Use the caller's files or diff. Otherwise use the current diff against the PR base, defaulting to `staging`, including the working tree and untracked files.

## Steps

1. Before execution, list available subagents and confirm `pstack.comment-sicko` or its `comment-sicko` alias is executable. Launch exactly one fresh-context, read-only Comment Sicko child through one asynchronous `workflowScript`. Pass the absolute worktree path and resolved scope. Do not restate its rules or ask it to edit.
2. Inspect its report and the diff. Reject scope escapes, exception-protected deletions, misstated `MUST KILL` reasons, and flags that treat kept intentional code as guilty. Code-shape findings about surprising repository-owned behavior stay actionable. A keep survives only with proof that it covers something the repository cannot change. Audit missed scoped lint and TypeScript suppressions. Correctness or safety suppressions stay actionable `MUST KILL` findings. Before accepting a thin `IMPORTANT` or `do not remove` kill or keep, load the `how` or `why` skill and investigate the named symbol. If doubt remains about a keep, delete the comment. If the report itself is unsupported, reject it and report why rather than applying it.
3. Fix trivial accepted findings directly by deleting dead code, dropping an unused parameter, using the real API, or removing the comment when the code already states the intent.
4. For accepted `MUST KILL` findings, sketch the smallest code-shape correction before editing. Follow repository architecture rules. Fix the root cause within scope and remove the workaround comment. Do not widen the task to unrelated instances. If the root cause lies outside scope, make the smallest safe in-scope fix and report the remaining work.
5. Constraint comments say things such as `do not remove`, `do not change wording`, or `talk to X before changing`. Keep only constraints imposed by something the repository cannot change. Offer the cheapest in-scope type, runtime check, test, or CI rule that can enforce the constraint. Wait for interactive approval before adding that enforcement. Without approval, delete the comment, report the unenforced constraint, and sketch the out-of-scope work.
6. Report the deletion count, rejected findings, fixes, encoding offers, approved encodings, unenforced constraints, and other open work.
