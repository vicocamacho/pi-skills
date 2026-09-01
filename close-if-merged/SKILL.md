---
name: close-if-merged
description: >
  Check whether the current branch's GitHub PR has been merged and, if so,
  clean up its isolated database and linked worktree, then close the dedicated
  Herdr workspace. Use when the user says "check if this is merged", "close
  this workspace if merged", "close this tab if merged", or "is the PR merged
  yet?".
---

# Close Workspace If PR Is Merged

Check the merge state of the PR for the current branch. If merged, remove the
isolated database and linked worktree, then close the dedicated Herdr workspace
containing all of its tabs and panes.

## Steps

### 1. Record the branch and worktree paths

```bash
git branch --show-current
git rev-parse --show-toplevel
git rev-parse --git-common-dir
```

If the branch is `staging`, `main`, or `master`, stop and tell the user there is
no feature PR to check.

Record the linked worktree's absolute path. Resolve the common Git directory to
an absolute path and use its parent as the main checkout root. Keep these values
before cleanup because the linked worktree directory will be removed.

### 2. Identify and verify the current workspace

```bash
herdr pane current --current
```

Parse `result.pane.workspace_id`, then inspect it:

```bash
herdr workspace get <workspace-id>
```

Proceed only when `result.workspace.worktree.is_linked_worktree` is `true` and
`result.workspace.worktree.checkout_path` resolves to the worktree path from
step 1. If either check fails, stop rather than risking closure of the main or
an unrelated workspace.

### 3. Look up the PR state

```bash
gh pr view <branch> --json state,mergedAt,url --jq '{state,mergedAt,url}'
```

If no PR exists (`gh` exits non-zero or returns empty), report that and stop.

### 4. Evaluate the state

- If `state` is not `MERGED`, report that the PR is still open or was closed
  without merging, include the PR URL, and do nothing further.
- If `state` is `MERGED`, proceed with cleanup.

### 5. Stop the worktree dev server

Before dropping databases, inspect every pane in the verified workspace:

```bash
herdr pane list --workspace <workspace-id>
```

The `live-test` skill labels its server pane `bin/dev [<port>] [<feature>]`. For
each pane whose label starts with `bin/dev [` and whose `cwd` or
`foreground_cwd` resolves to the linked worktree path, interrupt the foreground
process without closing the pane:

```bash
herdr pane send-keys <server-pane-id> ctrl+c
```

Read `PORT` from `<worktree-path>/.env`, defaulting to `3000`, and wait until no
process is listening on that port:

```bash
port=$(grep -E '^PORT=' <worktree-path>/.env 2>/dev/null | tail -1 | cut -d= -f2-)
port=${port:-3000}
for _ in 1 2 3 4 5 6 7 8 9 10; do
  lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1 || break
  sleep 0.5
done
! lsof -nP -iTCP:"$port" -sTCP:LISTEN -t >/dev/null 2>&1
```

If the port is still listening, report the failure and stop. Do not close the
server pane, its tab, or the workspace. If no matching server pane exists and
the port is not listening, continue normally.

### 6. Clean up the database and linked worktree

Run cleanup from the main checkout, not from inside the linked worktree.

If `<main-checkout-root>/bin/dev-worktree` exists, use it with the absolute
worktree path so nested branch names and custom worktree directory names resolve
correctly:

```bash
cd <main-checkout-root> && bin/dev-worktree remove <worktree-path>
```

If `bin/dev-worktree` is absent, fall back to plain Git:

```bash
git -C <main-checkout-root> worktree remove <worktree-path> --force
```

If cleanup fails, report the failure and do not close the workspace.

### 7. Close the dedicated workspace

Closing the workspace terminates every tab and pane in it, including any dev
server tab and the current Pi agent. Do not separately close server panes or
individual tabs.

Report the PR URL, merge timestamp, and successful worktree cleanup immediately
before issuing the final command:

```bash
herdr workspace close <workspace-id>
```

This must be the final command because it closes the pane running the skill.
