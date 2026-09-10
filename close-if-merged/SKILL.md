---
name: close-if-merged
description: >
  Check whether the current branch's GitHub PR has been merged or closed and,
  if so, discard local checkout changes and artifacts, clean up its isolated
  database and linked worktree, then close the dedicated Herdr workspace. Use
  when the user says "check if this is merged", "close this workspace if done",
  "close this tab if merged", or "is the PR finished?".
---

# Close Workspace If PR Is Finished

Check the state of the PR for the current branch. If it was merged or closed
without merging, discard the worktree's local checkout state, remove its
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

- If `state` is `OPEN`, report that the PR is still open, include the PR URL,
  and do nothing further.
- If `state` is `MERGED` or `CLOSED`, proceed with cleanup.
- For any other state, report it and stop.

Before stopping the server, record local checkout changes for the final report:

```bash
git -C <worktree-path> status --short
```

A GitHub `MERGED` or `CLOSED` state authorizes discarding modified tracked
files, staged changes, untracked files, and ignored artifacts in this worktree.
They must not block cleanup. This rule applies only after GitHub verifies that
the PR is no longer open. Never discard local work for an open PR or when no PR
exists.

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

Discard the finished worktree's tracked changes and every untracked or ignored
file before removal:

```bash
git -C <worktree-path> reset --hard HEAD
git -C <worktree-path> clean -ffdx
```

If either command fails, report the failure and stop. If
`<main-checkout-root>/bin/dev-worktree` exists, use it with the absolute
worktree path so nested branch names and custom worktree directory names resolve
correctly:

```bash
cd <main-checkout-root> && bin/dev-worktree remove <worktree-path>
```

If `bin/dev-worktree` is absent, fall back to plain Git:

```bash
git -C <main-checkout-root> worktree remove <worktree-path> --force
```

Do not treat the cleanup command's exit status alone as authoritative. Git can
remove the worktree registration and tracked checkout, then return non-zero
because ignored generated directories such as `tmp/` or `vendor/` remain.
Inspect both the registration and filesystem path after the command finishes:

```bash
git -C <main-checkout-root> worktree list --porcelain
test -e <worktree-path>
```

If the exact recorded path is still registered, report the failure and do not
close the workspace. If it is no longer registered but the path remains, remove
the residue only when the path is a directory rather than a symlink and it is
below `<main-checkout-root>/.worktrees/` rather than the `.worktrees` directory
itself:

```bash
rm -rf -- <worktree-path>
test ! -e <worktree-path>
```

The verified `MERGED` or `CLOSED` state authorizes deleting residue even when
the earlier status output listed local changes. This handles directory shells
and artifacts left by a partially successful `git worktree remove`.

Cleanup succeeds only when the exact path is absent from both
`git worktree list --porcelain` and the filesystem. Otherwise report the
remaining state and do not close the workspace.

### 7. Close the dedicated workspace

Closing the workspace terminates every tab and pane in it, including any dev
server tab and the current Pi agent. Do not separately close server panes or
individual tabs.

Report the PR URL, final state, merge timestamp when present, any discarded
local checkout changes, and successful worktree cleanup immediately before
issuing the final command:

```bash
herdr workspace close <workspace-id>
```

This must be the final command because it closes the pane running the skill.
