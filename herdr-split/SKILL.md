---
name: herdr-split
description: >
  Open a command or dev server in a Herdr split pane within the current session.
  Use only when the user explicitly asks to open something in a split, start a
  dev server in a split, run a command in a vertical or horizontal split, or
  split the pane and run something. Generic live-test and run-app requests use
  the live-test skill instead. Requires Herdr to be running and the current
  terminal to be a Herdr pane.
---

# Open a Command in a Herdr Split Pane

Split the current herdr pane and run a command (e.g. `bin/dev`) in the new pane,
without leaving the current session or opening a new workspace.

## Steps

### 1. Get the current pane ID

```bash
herdr pane current
```

Parse `pane_id` from the JSON result — this is the pane to split from.

### 2. Determine split direction

- Always use `--direction right` (vertical split, side by side)
- Ignore any user request for a horizontal/down split — vertical is the only supported direction

### 3. Determine the working directory and command

**If the user names a worktree or branch**, resolve its path:

```bash
herdr worktree list --json
```

Match `branch` or the last path segment against the user's description to find
`path`. If multiple worktrees match, ask the user to clarify.

If herdr is unavailable, fall back to:

```bash
git worktree list --porcelain
```

**If no worktree is mentioned**, omit `--cwd` and the new pane inherits the
current directory.

**If a worktree is active in the session** (added via `add_directory`), default
to using that worktree's path as `--cwd` for the split.

**Determine the dev command** — check for a `bin/dev` script in the worktree
root; that is the default for Rails projects using Foreman/Overmind. If absent,
check `package.json` for a `dev` script (`npm run dev`), then fall back to
`bin/rails server`.

**Find the port** — read `<worktree-path>/.env` for a `PORT=` line and report
the URL (`http://localhost:<PORT>`) in the summary. If no `.env` exists, omit
the URL.

### 4. Create the split

```bash
herdr pane split <current-pane-id> --direction right|down [--cwd <path>] --focus
```

Parse the new `pane_id` from the JSON result (`result.pane.pane_id`).

### 5. Run the command in the new pane

```bash
herdr pane send-text <new-pane-id> "<command>"
herdr pane send-keys <new-pane-id> enter
```

Use `send-text` + `send-keys enter` rather than `pane run`, so the user
sees the command in their shell history and can interact with it naturally.

### 6. Report

Tell the user:
- Which pane the command is running in
- The direction of the split
- The URL or port if a dev server was started

## Replacing an existing split

If the user says "redo the split", "wrong direction", or wants to close and
reopen:

1. Find the pane to close — either from prior context or `herdr pane list`.
2. Close it: `herdr pane close <pane-id>`
3. Repeat steps 4–5 with the corrected direction/cwd.

Note: `herdr pane close` may return `pane_not_found` if the user already
closed it manually — treat that as a no-op and proceed.

## Notes

- `herdr pane split` only accepts `--direction right` or `--direction down`.
  There is no `--direction left` or `--direction up`.
- `herdr pane list` does not accept a `--json` flag; its output is always JSON.
- `herdr pane split` and most other pane subcommands also do not accept `--json`;
  output is always JSON.
- To focus back on the original pane after splitting:
  `herdr pane focus --direction left` (or whichever direction returns to it).
- `herdr pane rename <pane-id> <label>` can label the new pane for clarity
  (e.g. `bin/dev`).
