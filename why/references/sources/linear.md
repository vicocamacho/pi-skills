# Linear tickets and project context

## What this source contains

- Issues describing features, bugs, and their motivation
- Issue comments, including scope changes and decision records
- Parent and sub-issue relationships
- Projects, initiatives, milestones, releases, and status updates
- Linear documents attached to issues, projects, or initiatives
- Labels that signal customer, compliance, incident, or performance motivation
- Attachments and linked pull requests

Linear often holds the product or business forcing function behind a change.

## Pi access

Use the direct tools exposed by the read-only `linear` MCP through the `pstack.why-linear` agent. The parent must confirm the server and tool catalog with `mcp({ server: "linear" })` before launch.

Useful tools in the current catalog include:

- `linear_get_issue`
- `linear_list_issues`
- `linear_list_comments`
- `linear_get_project`
- `linear_list_projects`
- `linear_list_documents`
- `linear_get_document`
- `linear_get_status_updates`
- `linear_get_initiative`
- `linear_list_initiatives`
- `linear_get_milestone`
- `linear_list_milestones`

If the live catalog differs, use the exact names and schemas returned by Pi. Do not guess tool arguments.

## How to search it

1. **Open linked tickets first.** For each ticket ID found in commits or PR bodies, call `linear_get_issue` with relations enabled when useful. Then call `linear_list_comments` with that issue ID.
2. **Try several keyword searches.** Call `linear_list_issues` with the feature name, symbols, user-facing terms, error text, and likely business phrasing. Record every query, including null results.
3. **Walk the issue hierarchy.** Use returned parent IDs and project IDs to retrieve broader context. Parent issues and projects often explain the motivation that tactical sub-issues omit.
4. **Read discussion fully.** Fetch all relevant comment pages. Inline comments may attach to quoted description text and can record later scope changes.
5. **Inspect the project.** Call `linear_get_project` with resources and milestones when available. Review project comments and status updates when they bear on the decision.
6. **Search Linear documents.** Use `linear_list_documents` with keyword, project, initiative, team, creator, or date filters. Fetch candidate documents with `linear_get_document` and read their full content.
7. **Check labels, milestones, initiatives, and releases.** These can tie work to a customer request, compliance deadline, incident follow-up, launch, or performance effort.
8. **Compare dates with the code anchor.** A stale ticket may describe an abandoned plan. Record created, updated, completed, and canceled dates when available.

## Strong evidence

- An issue description stating the business or user problem
- A comment recording a decision and rejected alternative
- A parent issue or project naming the broader initiative
- A Linear document with a problem statement or alternatives section
- A project status update explaining a scope or priority change
- Labels such as `customer:*`, `incident-followup`, `compliance`, or `perf-regression`

## Common pitfalls

- **Scope drift.** Read the issue description, comments, parent, and status history before treating the original scope as final.
- **Boilerplate rationale.** Generic template text does not prove motivation.
- **Stale plans.** Compare ticket and document dates with the implementation and PR discussion.
- **Partial pagination.** Continue through cursors when more issues, comments, or documents exist.
- **Missing comments.** `linear_get_issue` does not replace `linear_list_comments`.
- **Private content.** Report inaccessible issues or documents as gaps.
- **Linear documents are not independent document-system coverage.** Report them as supporting Linear evidence unless a separate long-form document MCP was searched.

## What to return

For each relevant item, include:

- ID, title, and URL
- item type, such as issue, comment thread, project, initiative, milestone, status update, or document
- exact motivation or decision quotation
- author and relevant dates
- labels, parent, project, initiative, or release context
- whether the evidence is direct or circumstantial

Also return every query that produced no relevant results and any inaccessible content.
