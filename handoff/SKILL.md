---
name: handoff
description: >
  Prepare an isolated worktree and hand a development task to a new Pi agent
  that must implement the work, submit a pull request, and prepare the result
  for live testing. Use when the user says "handoff", "hand this off",
  "handoff implement", or asks to prepare a worktree whose agent should finish
  through PR submission and browser testing. The task may be a ticket or a
  freeform description.
---

# Handoff

Prepare a primary isolated worktree with the `worktree-start` skill, then start a full Pi agent in that worktree and explicitly invoke its `implement` skill. The handoff agent owns the task and may orchestrate subagents from inside its new session; subagents never replace the handoff agent or the primary worktree.

## Steps

1. Extract the development task from the user's request. Accept ticket-backed requests such as `handoff implement HELIX-123` and freeform requests such as `handoff implement user authentication`. Strip one leading wrapper such as `handoff implement`, `handoff implementation of ticket`, or `hand this off`. Preserve every word in the remaining task. If no task remains, ask for one.
2. When the task names a Linear issue identifier or URL, retrieve the issue from Linear before creating the worktree. Record its identifier, title, URL, and exact `gitBranchName`. Use the title for the workspace label and keep the identifier plus any user qualifiers in the development task. If the issue cannot be resolved or has no branch name, stop and report the problem rather than inventing ticket metadata.
3. Load and follow the `worktree-start` skill:
   - For a Linear ticket, use the issue's exact `gitBranchName` and the resolved development task. Do not derive another branch name.
   - For a freeform task, let `worktree-start` derive the branch, worktree path, workspace label, and session name from the task.
4. During the Herdr handoff, replace the ordinary task instruction with an explicit skill command. Keep `/skill:implement` as the first token so Pi loads the skill rather than relying on automatic matching:

   ```text
   /skill:implement <resolved ticket-backed or freeform development task>

   You are the primary handoff agent and own this pre-created worktree, the
   implementation, and delivery. Read the relevant project field guides before
   making changes. You are explicitly authorized and required to orchestrate
   subagents from this session. Load the pi-subagents skill, inspect enough of
   the repository to identify safe ownership boundaries, and proceed as follows:

   - For a multi-seam change, use one asynchronous top-level workflow with
     non-overlapping implementation lanes. Give each child writer a separate
     managed worktree, then integrate its accepted work into this primary
     handoff worktree and validate the combined result here.
   - For a single-seam change, keep implementation in this session and use
     bounded subagents for useful research, test analysis, or validation rather
     than creating overlapping writers.
   - Route token-heavy exploration — broad code searches, reading many files,
     long test or log output — to scout or researcher subagents that return
     bounded findings with evidence. Keep raw exploration output out of this
     session so its context stays small.
   - Before PR submission, load and run the `pre-submit-review` skill. It owns
     the complete gate: four parallel specialist reviews, resolution of their
     findings, then a fresh adversarial review of the integrated result. Do not
     launch an extra generic reviewer or separate comment-reviewer pass. Follow
     its rerun rules after fixes and record the gate evidence in HANDOFF-STATE.md.
     `challenge-review` is separate existing-PR feedback adjudication, not part
     of this pre-PR gate.
   - Do not permit nested fanout. Keep task interpretation, integration, final
     acceptance, PR submission, and publication decisions in this session.

   Before any implementation work, create `HANDOFF-STATE.md` at the worktree
   root and keep it out of git:

       grep -qxF HANDOFF-STATE.md "$(git rev-parse --git-common-dir)/info/exclude" \
         || echo HANDOFF-STATE.md >> "$(git rev-parse --git-common-dir)/info/exclude"

   Record the task, these delivery requirements, the plan, decisions made,
   changed files, validation status, and the exact next step. Update it at
   every phase boundary so a fresh agent can resume from it alone.

   Context rollover is authorized only after an automatic compaction event
   has actually occurred, or when the user explicitly requests a primary-agent
   transfer. Follow the implement skill's ownership and rollover gate. Record
   the observed compaction event or explicit user instruction in
   `HANDOFF-STATE.md` before creating a replacement agent. Large output,
   estimated context pressure, workflow timeouts, failed reviews, and expired
   supervisor requests are not rollover triggers. Without a valid trigger,
   summarize evidence and recover the failed lane in this session; retain
   primary ownership even when recovery is blocked.

   When the gate is satisfied, update `HANDOFF-STATE.md`, start a fresh Pi
   agent in this same workspace (split a pane in this worktree,
   `herdr agent start`, then prompt it with
   `/skill:implement Resume from HANDOFF-STATE.md in this worktree`), confirm
   it acknowledged ownership, report the handover, and stop working. Exactly
   one agent owns the worktree at a time.

   Add or update tests and run the required validation. When the implementation
   is ready, submit the pull request using the repository's PR workflow. After
   submitting the PR, invoke the live-test skill so the development server is
   running and the app is open in the browser for review. Report the subagent
   workflow and review evidence, PR URL, test results, live-test URL, residual
   risks, and the principles used during implementation.
   ```

5. Submit the augmented instruction without waiting for the new agent to finish, then focus its Herdr workspace as required by `worktree-start`.
6. Report the task source, worktree, branch, port, workspace, pane, agent name, and whether Herdr accepted the task.

## Rules

- A ticket is optional. Do not search for or create one for a freeform task.
- Do not implement the task or launch implementation subagents in the caller's checkout.
- Always create the primary handoff worktree and start its full Pi agent before any implementation orchestration begins.
- Do not submit a PR or start the development server before handing off. The new worktree agent owns implementation, subagent orchestration, integration, validation, PR submission, and live testing.
- Use Linear's exact branch name for a resolved ticket.
- Do not derive branch or workspace names from the appended completion requirements.
- Preserve all setup and cleanup safety rules from `worktree-start`.
- Every handed-off implementation must pass [Pre-submit review](../pre-submit-review/SKILL.md) before PR submission. That skill owns all five read-only reviewers and their reruns; do not add duplicate review launches. `challenge-review` does not satisfy this gate.
- The handoff agent keeps its own context lean: bulky exploration belongs in subagents.
- `HANDOFF-STATE.md` is mandatory, lives at the worktree root, must be excluded from git via `info/exclude`, and must never appear in the PR diff.
- Rollover requires an observed automatic compaction event under the task's authorization or an explicit user request to transfer primary ownership. Record that trigger before creating the replacement agent. Task size, output volume, elapsed time, and lane failures are not triggers.
- An authorized rollover transfers ownership to exactly one fresh agent in the same workspace; the outgoing agent stops working after the new agent acknowledges. Rollover does not change the task, branch, or delivery requirements.
- Subagents are children of the handoff agent. They do not replace the handoff agent, own the primary handoff worktree, or report directly to the caller.
- A subagent infrastructure failure blocks that lane. The new agent must report it rather than silently switching execution modes.
- `live-test` must run only after the pull request has been submitted.
