---
name: sweep-merged-tabs
description: >
  Find idle Pi agents in linked-worktree Herdr workspaces and ask one agent per
  workspace to run "close if merged". Use when the user says "sweep merged
  tabs", "sweep merged workspaces", "clean up idle agents", "close any merged
  workspaces", or "check all idle agents for merged PRs".
---

# Sweep Merged Workspaces

Find each linked-worktree Herdr workspace with an idle Pi agent and ask one
agent in that workspace to run the `close-if-merged` workflow. Each target agent
checks its own PR and, when merged, removes its database and worktree before
closing its entire workspace.

## Steps

### 1. Identify the current pane and workspace

```bash
herdr pane current --current
```

Parse `result.pane.pane_id` and `result.pane.workspace_id`. Exclude the entire
current workspace from the sweep so this skill cannot arrange for its own
workspace to close underneath it.

If the command fails, stop and tell the user the sweep needs a Herdr terminal.

### 2. Find linked-worktree workspaces

```bash
herdr workspace list
```

Collect workspaces where `worktree.is_linked_worktree` is `true`, excluding the
current workspace ID. Ignore the main checkout workspace and any workspace that
has no linked-worktree metadata.

Keep each eligible workspace's `workspace_id`, `label`, and `active_tab_id` for
selection and reporting.

### 3. Find idle Pi agents

```bash
herdr agent list
```

Collect agents where all of the following are true:

- `agent` is `"pi"`
- `agent_status` is `"idle"` or `"done"`
- `workspace_id` belongs to an eligible linked-worktree workspace
- `pane_id` is not the current pane

Group candidates by `workspace_id` so only one agent receives the command in
each workspace. If a workspace has one candidate, use it. If it has multiple
candidates, prefer the sole candidate whose `tab_id` equals the workspace's
`active_tab_id`. If that does not identify exactly one agent, skip the
workspace and report the ambiguity rather than triggering competing cleanup.

Do not include `working`, `blocked`, or `unknown` agents.

### 4. Ask each selected agent to check its workspace

Use the agent surface with the pane ID as the target because `pi` may not be a
unique agent name:

```bash
herdr agent prompt <pane-id> "close if merged"
```

Do not use `--wait`. A merged PR causes the target agent to close its own
workspace, which may prevent a lifecycle wait from settling normally.

### 5. Report

List each messaged workspace by label and workspace ID, together with the target
pane ID and the total number of workspaces contacted. Also list any workspace
skipped because multiple idle Pi agents made the target ambiguous.

The target agents handle PR checks and cleanup independently. An unmerged or
missing PR leaves its workspace untouched.
