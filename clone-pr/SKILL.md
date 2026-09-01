---
name: clone-pr
description: Clone a PR into a git worktree, prepare it for local review or work, and hand it to the active terminal host when supported. Use when the user says "clone PR", "checkout PR in worktree", "pull down PR #123", "review PR locally", or wants to get a PR running locally without disturbing their current checkout.
argument-hint: "<PR number or URL>"
---

# Clone a PR into a worktree

Clone a pull request into an isolated Git worktree and prepare its development
environment. Worktree setup stays independent of terminal layout. After setup,
a supported terminal integration may open the worktree and launch a separate Pi
session.

## Steps

### 1. Resolve the PR and task

Parse `$ARGUMENTS` for a PR number, `#123`, or GitHub URL. If none is present,
ask the user which PR to clone.

Fetch the PR metadata:

```bash
gh pr view <number> --json number,headRefName,title,baseRefName
```

Keep the user's requested work separate from the PR identifier. If the request
only identifies a PR, use this default task for the new Pi session:

```text
Review PR #<number>, "<title>", against <baseRefName>. Report only actionable findings with file and line references.
```

If the user asked to fix, test, explore, or continue work on the PR, preserve
that instruction instead of replacing it with the review default.

### 2. Create or reuse the worktree

Use `.worktrees/<headRefName>` when the repository follows the `.worktrees`
convention. Store the resulting absolute path for setup and handoff.

Before reusing an existing worktree, verify that Git recognizes it and inspect
its status. Do not reset, clean, or overwrite local changes. If it is clean,
fetch and update the PR branch. If it contains changes, stop and ask whether to
reuse it as-is or choose another path.

For a new worktree, prefer the repository's manager when present:

```bash
bash scripts/worktree-manager.sh create <headRefName>
```

Otherwise create it with Git:

```bash
git fetch origin <headRefName>
git worktree add .worktrees/<headRefName> -b <headRefName> origin/<headRefName>
```

If the local branch already exists, attach the worktree to that branch instead
of trying to create it again. If `.worktrees` is used and is not ignored, add
it to `.gitignore`.

### 3. Run project setup

For a newly created worktree, run setup from the worktree and select only the
first available option:

1. `bin/dev-worktree`
2. `bin/setup --skip-server`, but only when `bin/setup` supports that option
3. `script/setup`
4. `make setup`, when the `Makefile` defines a `setup` target
5. Nothing, and report that setup was skipped

When `bin/dev-worktree` exists, it is mandatory because it creates the isolated
database, test database, environment file, and port. If it fails, stop and
report the error. Do not fall through to a generic setup script that may use the
main checkout's database.

When reusing a worktree, verify that its environment is already configured. If
`bin/dev-worktree` exists but the worktree has no `.env`, run it before handoff.

### 4. Hand off to the active terminal host

Only after setup succeeds or an existing environment is verified, check whether
the current session is running inside Herdr:

```bash
test "${HERDR_ENV:-}" = 1
```

When the check succeeds, load the `herdr` skill and follow its "Open a prepared
worktree and launch Pi" flow. Pass these values to the Herdr integration:

- Worktree path: the absolute PR worktree path
- Worktree slug: a short slug derived from the PR branch
- Session name: `pr-<number>-<branch-slug>`, shortened when needed
- Task instruction: the user request or review default from step 1
- Focus: focus the new workspace after Herdr accepts the task

The Herdr integration owns workspace creation, pane checks, Pi startup, prompt
submission, and focus. This skill must not duplicate those commands. If the
handoff fails, leave the prepared worktree intact and report the error.

When the check fails, do not select another terminal host automatically. Report
the command the user can run to open Pi in the prepared worktree:

```bash
cd <absolute-worktree-path> && pi --name "pr-<number>-<branch-slug>"
```

For any follow-up tool or subagent work performed by the current session, use
the absolute worktree path. Pass it as `cwd` to subagents so they do not run
against the main checkout.

### 5. Report

Report:

```text
PR #<number> cloned into <absolute-worktree-path>
Title:  <title>
Branch: <headRefName>
Base:   <baseRefName>
Setup:  <command run, verified existing setup, or why setup was skipped>
Task:   <task submitted or prepared>
Host:   <Herdr workspace, pane, and agent details, or "no host selected">
Port:   <port from .env, when present>
URL:    http://localhost:<port>, when present

To start the development server:
  cd <absolute-worktree-path> && bin/dev
```

Outside Herdr, include the manual Pi command from step 4.

## Cleanup

Run cleanup from the main checkout. Prefer the worktree-aware command when it
exists:

```bash
bin/dev-worktree remove <absolute-worktree-path>
```

Otherwise use Git:

```bash
git worktree remove <absolute-worktree-path>
```

## Safety rules

- Finish or verify setup before delegating to a terminal host, launching an
  agent, or running application commands in the worktree.
- Never reset, clean, or overwrite a reused worktree with local changes.
- If `bin/dev-worktree` exists and the worktree has no `.env`, do not run
  `bin/rails`; run `bin/dev-worktree` first.
- Do not add the worktree to the current Pi session when a separate session
  will own the PR work.
