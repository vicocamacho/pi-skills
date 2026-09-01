---
name: worktree-start
description: >
  Create a git worktree for a new feature branch, set up its development
  environment, and hand it to the active terminal host when supported. Use
  when the user says "start work in a worktree", "create a
  worktree", "new feature branch in worktree", "work on X in a worktree", or
  "set up a worktree for". Not for cloning existing PRs (use clone-pr for that).
---

# Start work in a worktree

Create a new git worktree from a feature branch and prepare its isolated
development environment. Worktree setup stays independent of terminal layout.
After setup, a supported terminal integration may open the worktree and launch
a separate Pi session.

## Steps

### 1. Determine the branch name

Parse `$ARGUMENTS` for a branch name or feature description.

- If a branch name is given directly, use it.
- If a description is given, derive `feature/<slugified-description>`.
- If nothing is provided, ask the user what they want to work on and derive the
  branch name from their answer.

Keep the feature description for the final handoff. If the user provides only a
branch name, ask for the development task before creating the worktree.

### 2. Choose the base branch

Default to the repository's primary integration branch. Detect it:

```bash
git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@'
```

If that fails, fall back to `staging`, then `main`, then `master`, using the
first branch that exists on the remote.

Fetch the latest base branch before creating the worktree:

```bash
git fetch origin <base>
```

### 3. Determine the worktree path

Check for a `.worktrees/` convention. If `.worktrees/` exists or `.gitignore`
contains `.worktrees`, use:

```text
.worktrees/<branch-name-slug>
```

Otherwise, place the worktree beside the repository root:

```text
../<repository-name>-<branch-name-slug>
```

Use the project's own slug convention when one exists. Check
`bin/dev-worktree --info` when that command is available.

### 4. Create the worktree

For a new branch:

```bash
git worktree add <path> -b <branch> origin/<base>
```

If the branch already exists locally or remotely, fetch it when possible and
check it out instead of trying to create it again:

```bash
git fetch origin <branch> 2>/dev/null
git worktree add <path> <branch>
```

If `.worktrees` is used and is not ignored, add it to `.gitignore`.

### 5. Run project setup

Run setup from the new worktree. Select only the first available option:

1. `bin/dev-worktree`
2. `bin/setup --skip-server`, but only when `bin/setup` supports that option
3. `script/setup`
4. `make setup`, when the `Makefile` defines a `setup` target
5. Nothing, and report that setup was skipped

`bin/dev-worktree` is mandatory when present because it creates the isolated
database, test database, environment file, and port used by the worktree.

If `bin/dev-worktree` fails, stop and report the error. Do not fall through to a
generic setup script that may use the main checkout's database.

### 6. Hand off to the active terminal host

Only after setup succeeds, check whether the current session is running inside
Herdr:

```bash
test "${HERDR_ENV:-}" = 1
```

When the check succeeds, load the `herdr` skill and follow its "Open a prepared
worktree and launch Pi" flow. Pass these values to the Herdr integration:

- Worktree path: the absolute path created in step 4
- Worktree slug: the directory or branch slug
- Session name: a short name derived from the slug
- Task instruction: the feature description collected in step 1
- Focus: focus the new workspace after Herdr accepts the task

The Herdr integration owns workspace creation, pane checks, Pi startup, prompt
submission, and focus. This skill must not duplicate those commands. If the
handoff fails, leave the prepared worktree intact and report the error.

When the check fails, do not select another terminal host automatically. Report
the command the user can run to open Pi in the prepared worktree:

```bash
cd <absolute-path> && pi --name "<worktree-slug>"
```

### 7. Report the handoff

Report:

```text
Worktree created for <branch>
Path:  <absolute-path>
Base:  <base-branch>
Setup: <command run, or why setup was skipped>
Port:  <port from .env, when present>
URL:   http://localhost:<port>, when present
Task:  <feature description>
Host:  <Herdr workspace, pane, and agent details, or "no host selected">

To start the development server:
  cd <absolute-path> && bin/dev

To clean up:
  bin/dev-worktree remove <branch>
```

Outside Herdr, include the manual Pi command from step 6. If `bin/dev-worktree`
is absent, use the plain Git cleanup command instead:

```bash
git worktree remove <absolute-path>
```

## Safety rules

- Finish setup before delegating to a terminal host, launching an agent, or
  running application commands in the worktree.
- If `bin/dev-worktree` exists and the worktree has no `.env`, do not run
  `bin/rails`; run `bin/dev-worktree` first.
- Never run `bin/rails db:seed` or `bin/setup` without `--skip-server` unless
  the user explicitly asks.
- Do not add the worktree to the current Pi session. It is intended for a
  separate session.
- The worktree shares Git history and objects with the main checkout. Commits,
  stashes, and fetches are visible from both locations.
