---
name: handoff
description: >
  Prepare an isolated worktree and hand a development task to a new Pi agent
  that must implement the work, submit a pull request, and prepare the result
  for live testing. Use when the user says "handoff", "hand this off", or asks
  to prepare a worktree whose agent should finish through PR submission and
  browser testing.
---

# Handoff

Prepare a worktree with the `worktree-start` skill, then give the new Pi agent
the full delivery task.

## Steps

1. Treat the user's arguments as the original development task. If no task was
   provided, ask for one.
2. Load and follow the `worktree-start` skill. Use only the original task when
   deriving the branch name, worktree path, workspace label, and session name.
3. During the Herdr handoff, replace the ordinary task instruction with the
   original task plus these completion requirements:

   ```text
   Complete the requested work in this worktree. Read the relevant project
   field guides before making changes. Add or update tests and run the required
   validation. When the implementation is ready, submit the pull request using
   the repository's PR workflow. After submitting the PR, invoke the live-test
   skill so the development server is running and the app is open in the
   browser for review. Report the PR URL, test results, live-test URL, and any
   residual risks.
   ```

4. Submit the augmented instruction without waiting for the new agent to
   finish, then focus its Herdr workspace as required by `worktree-start`.
5. Report the worktree, branch, port, workspace, pane, agent name, and whether
   Herdr accepted the task.

## Rules

- Do not implement the task in the caller's checkout.
- Do not submit a PR or start the development server before handing off. The
  new worktree agent owns implementation, validation, PR submission, and live
  testing.
- Do not derive branch or workspace names from the appended completion
  requirements.
- Preserve all setup and cleanup safety rules from `worktree-start`.
- `live-test` must run only after the pull request has been submitted.
