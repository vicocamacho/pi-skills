---
name: worktree-cleanup
description: >
  Find and clean up orphaned worktree databases and empty worktree directories.
  Use when the user says "clean up worktrees", "drop orphaned DBs",
  "worktree garbage collect", or "prune worktree databases".
---

# Worktree Cleanup

Find and clean up orphaned worktree databases and directories. Uses `bin/dev-worktree` when the worktree still exists, falls back to manual cleanup for fully orphaned databases.

## Steps

### 1. Fetch latest base branch and check for merged worktrees

Fetch the base branch so the merged check uses the latest remote state:

```bash
git fetch origin staging
```

List active worktrees:

```bash
bin/dev-worktree list
```

**IMPORTANT: The worktree directory name and the actual branch name often differ**
(e.g., directory `fix-portal-login-email` but branch `fix/portal-login-email-forwarding`).
Always resolve the real branch before checking PR status:

```bash
git -C .worktrees/<dir> branch --show-current
```

Use the **actual branch name** (not the directory name) for all subsequent
`gh pr list --head`, `git branch --merged`, and `git diff` checks.

Check which branches are merged into the up-to-date base branch:

```bash
git branch --merged origin/staging
```

`git branch --merged` misses squash-merged and rebase-merged branches because
their original commits are not ancestors of the target. For every active
worktree branch that is **not** detected by `--merged`, also check the PR
state on GitHub using the **actual branch name**:

```bash
gh pr list --head <actual-branch> --state merged --json number,title --jq '.[0].number'
```

If that returns nothing, also check all states to catch closed/open PRs:

```bash
gh pr list --head <actual-branch> --state all --json number,title,state --jq '.[]'
```

If this returns a merged PR number, the branch was squash/rebase-merged and is safe
to clean up.

Branches whose PR was **closed without merging** are also cleanup candidates —
the work was abandoned or superseded. Include them alongside merged worktrees
when presenting options to the user.

**Check local changes, but let a verified merged PR override them:**

`git branch --merged` can flag a branch as merged even when the worktree
contains uncommitted work. This happens when no commits have been pushed and
the branch HEAD still points to a staging commit. An ancestry check alone does
not authorize deleting local work.

For every candidate identified by `--merged` or a merged/closed PR, run:

```bash
git -C .worktrees/<dir> status --short
```

Apply these rules:

- When GitHub reports the branch's PR state as `MERGED`, include the worktree
  even when status lists modified, staged, or untracked files. Note that cleanup
  will discard them. Ignored artifacts also do not block cleanup.
- When only `git branch --merged` identifies the branch, exclude a dirty
  worktree and report `has uncommitted changes; skipped`.
- When GitHub reports a PR closed without merging, exclude a dirty worktree and
  report the same reason. Do not discard abandoned local work automatically.

Before removing a verified merged PR's dirty worktree, discard tracked changes
and every untracked or ignored file:

```bash
git -C .worktrees/<dir> reset --hard HEAD
git -C .worktrees/<dir> clean -ffdx
```

Then use the project script for any eligible worktree whose branch is merged or
closed:

```bash
bin/dev-worktree remove <branch-or-path>
```

This drops the development, test, and parallel worker databases, removes the
worktree, and deletes the branch when Git considers it fully merged. Prefer it
over manual cleanup whenever the worktree still exists.

### 2. Find fully orphaned databases

After removing merged worktrees, check for leftover databases with no matching worktree:

```bash
psql -lqt | cut -d'|' -f1 | grep -E 'helix_(development|test)_' | sed 's/^ *//'
```

Cross-reference against active worktrees from `git worktree list`. Databases with no matching worktree are **orphaned**.

### 3. Exclude default databases

**Never touch** these default databases or their parallel workers:
- `helix_development`
- `helix_test`
- `helix_test_0`, `helix_test_1`, ... (default parallel workers)

Only databases with a worktree slug suffix are candidates for cleanup.

### 4. Confirm with user

Present the orphaned databases grouped by original worktree slug. Ask the user to confirm before dropping. Use `ask_user` with clear options.

### 5. Drop confirmed databases

```bash
dropdb <database_name>
```

For each slug being cleaned up, also find and drop its parallel worker databases:

```bash
psql -lqt | cut -d'|' -f1 | sed 's/^ *//' | grep -E '^helix_test_<slug>_[0-9]+$'
```

### 6. Clean up empty worktree directories

```bash
find .worktrees -type d -empty -delete 2>/dev/null
```

### 7. Report

Print a summary:

```
✓ Cleaned up N orphaned worktrees/databases:
  - <branch> via bin/dev-worktree remove (if applicable)
  - helix_development_<slug> (dropped)
  - helix_test_<slug> (dropped)
  - helix_test_<slug>_0..M (N parallel worker DBs dropped)

✓ Removed empty .worktrees/ directories
```
