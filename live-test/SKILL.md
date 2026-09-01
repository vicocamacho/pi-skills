---
name: live-test
description: >
  Start the dev server for the current worktree in a new Herdr tab and open the
  browser pointing at its port. Use when the user says "live test", "run the
  app", "open the app", "start the server and open the browser", or "let me
  see it in the browser".
---

# Live Test: Start Server in a New Tab and Open Browser

Start `bin/dev` in a new Herdr tab for the current worktree, append the port to
the tab's default number, label its root pane, and open the browser at the app's
URL.

Never use `herdr pane split` for this skill. Never use a background or detached
launch. Always create a focused tab in the caller's current Herdr workspace and
run the server in that tab's root pane.

## Steps

### 1. Resolve the worktree root and port

The worktree root is the directory the session is working in. Use
`git rev-parse --show-toplevel` if in doubt.

Read the port from `<worktree-root>/.env`:

```bash
grep "^PORT=" <worktree-root>/.env
```

If `.env` is absent or has no `PORT=` line, the port defaults to `3000`.

Derive the feature label from the worktree directory name:

```bash
feature=$(basename "$worktree_root")
```

For example, `/repo/.worktrees/add-intake-step-configuration-value` produces
`add-intake-step-configuration-value`.

### 2. Get the current workspace ID

```bash
herdr pane current --current
```

Parse `result.pane.workspace_id`. If this fails, stop and tell the user the
live test needs a Herdr terminal.

### 3. Create and label a focused tab

Build the tab and pane labels from the port, default tab number, and feature:

```text
<TAB_NUMBER> [<PORT>]
```

```text
bin/dev [<PORT>] [<FEATURE>]
```

Create the tab in the current workspace with the worktree as its working
directory. Do not pass `--label`; create it with its default numeric label so
that number can be retained in the renamed label.

```bash
herdr tab create \
  --workspace <workspace-id> \
  --cwd <worktree-root> \
  --focus
```

Parse the tab ID from `result.tab.tab_id`, the default tab number from
`result.tab.number`, and the server pane ID from `result.root_pane.pane_id`.
Rename the tab and label the pane:

```bash
herdr tab rename <tab-id> "<TAB_NUMBER> [<PORT>]"
herdr pane rename <server-pane-id> "bin/dev [<PORT>] [<FEATURE>]"
```

### 4. Start the dev server

```bash
herdr pane send-text <server-pane-id> "bin/dev"
herdr pane send-keys <server-pane-id> enter
```

Do not fall back to `interactive_shell` or a detached/background launch.

### 5. Open the browser

Run `bin/open-browser` from the worktree root. It reads `PORT` from `.env`
automatically and opens the correct URL:

```bash
cd <worktree-root> && bin/open-browser
```

### 6. Report

Tell the user:
- The URL the browser was pointed at (`http://localhost:<PORT>`)
- Which tab and pane the server is running in
- The tab label, including its original number and the port
- The pane label, including the port and feature
