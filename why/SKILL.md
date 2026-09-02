---
name: why
description: "Use for 'why does X work this way', 'why we picked Y', design rationale, regressions, postmortems, or data-backed thresholds. Discovers available MCPs and queries each evidence category (source control, issue tracker, long-form docs, real-time chat, infrastructure observability, error tracking, product analytics warehouse) in parallel, then returns a cited read on decisions and tradeoffs. Use how for runtime behavior."
disable-model-invocation: true
---

# Why

Investigate the motivation and intent behind code. Find the product, business, operational, and historical constraints that shaped it. Use `how` for runtime behavior. Use `why` for the forces that led to the current design.

Historical evidence is fragmented. Commits, PRs, tickets, documents, chat, telemetry, error tracking, and analytics may disagree or be missing. Collect evidence before forming a narrative. Report null results and unavailable sources alongside positive findings.

## Operating posture

- **Evidence before narrative.** Gather sources first. Do not choose a story and recruit evidence for it.
- **Cite intent claims.** Cite a commit, PR, ticket, document, conversation, incident, metric, or code comment. Uncited intent is inference.
- **Separate mechanics from motivation.** Code shows what happens. It rarely proves why the behavior exists.
- **Preserve contradictions.** Show conflicting sources instead of silently choosing one.
- **Name gaps.** State which sources and queries returned nothing or could not be searched.
- **Calibrate language.** Use confident causal language only for direct or strongly supported evidence. Use "appears to", "likely", or "suggests" for inference.
- **Treat user hypotheses as candidates.** Check them independently rather than confirming them by default.

Read `references/epistemics.md` before synthesizing. Its confidence tiers and phrasing rules are part of the output contract.

## Pi setup

This installation currently defines three user-scoped agents:

| Agent | Purpose | Tools |
| --- | --- | --- |
| `pstack.why-git` | Source control, PRs, in-repo history | `read`, `grep`, `find`, `ls`, `bash` |
| `pstack.why-linear` | Linear issues, comments, projects, and documents | Direct tools from `mcp:linear` |
| `pstack.why-synthesizer` | Synthesis plus source-control and Linear citation checks | Repository inspection, `bash`, and `mcp:linear` |

The Linear MCP is configured against its read-only endpoint. The Git and synthesizer agents have `bash`, so their read-only behavior is a command contract rather than a filesystem sandbox. They may run inspection commands only. They must not edit files, change Git state, call write APIs, or modify external systems.

Before launching children:

1. Run `subagent({ action: "list" })` and confirm the required `pstack.why-*` agents are executable.
2. Run `subagent({ action: "models" })` before passing explicit models.
3. Run `mcp({})` to inspect configured servers. For each candidate server, run `mcp({ server: "<name>" })` to inspect its tools and instructions.
4. Build a coverage map across all seven evidence categories. A server counts as searchable only when a matching executable investigator profile exposes its direct tools.
5. Copy exact `provider/id` values from the live registry. Append Pi thinking suffixes such as `:low` or `:max` only when needed. Omit `model` if no preferred model is available.

Preferred model mapping when available:

| Role | Preferred model |
| --- | --- |
| Investigators | `openai-codex/gpt-5.6-sol:low` |
| Synthesizer | `anthropic/claude-fable-5:max` |

Do not pass host-specific model aliases or unlisted model IDs.

## Evidence categories and current coverage

Build the coverage map at run time. Never claim a source was searched merely because its playbook exists.

1. **Source control history.** Git history, GitHub PRs, code comments, tests, ADRs, and changelogs. Always search through `pstack.why-git`.
2. **Issue or ticket tracker.** Linear, Jira, GitHub Issues, Plane, or Shortcut. Search Linear through `pstack.why-linear` when connected.
3. **Long-form documents.** Notion, Confluence, Google Docs, Coda, or another document MCP. Linear project documents may be searched as supporting Linear evidence, but that does not prove an independent long-form document system was searched.
4. **Real-time team chat.** Slack, Discord, Microsoft Teams, or Mattermost.
5. **Infrastructure observability.** Datadog, New Relic, Honeycomb, Grafana, or Splunk.
6. **Error or exception tracking.** Sentry, Rollbar, Bugsnag, or Airbrake.
7. **Product analytics warehouse.** Databricks, Snowflake, BigQuery, ClickHouse, dbt, or Redshift.

With the current configuration, source control and Linear are searchable. Mark the other categories unavailable unless `mcp({})` and `subagent({ action: "list" })` show a connected server and matching investigator profile.

To add another category later:

1. Configure and authenticate its MCP server.
2. Connect once and restart Pi so direct-tool metadata is cached.
3. Create a dedicated investigator agent whose strict tools include `mcp:<server-name>`.
4. Add that executable agent to this skill's category mapping.

Do not give one generic child every MCP. One investigator owns one evidence source or category so searches, null results, and citations remain attributable.

## Pi orchestration

Use one top-level `subagent` call for the investigation. Every child runs inside one async `workflowScript`:

- Launch all available investigators with one `runs.all([...])`.
- Await the ordered investigator array before launching the synthesizer with `runs.run(...)`.
- Use stable keys such as `source-control` and `linear-tickets`.
- Set `context: "fresh"`, `async: true`, and `mission: false` on the top-level call.
- Set `output: false` on children unless the user requested durable reports.
- Do not pass `acceptance` for these investigation and synthesis children.
- `runs.all` returns an ordered array. Use array indexes or `.map(...)`, never a key property lookup.
- Do not use `async: false`. In an interactive session, return control and let Pi wake the session on completion. Use `subagent_wait` only when the skill must deliver the answer in the current turn.

The workflow sandbox cannot read prompt files or call `mcp` for discovery. The parent must perform discovery, read the relevant templates and playbooks, fill every placeholder, JSON-encode the completed task strings, and interpolate them into `workflowScript` before launch.

A two-source investigation has this shape:

```javascript
const findings = await runs.all([
  {
    key: "source-control",
    agent: "pstack.why-git",
    task: "<filled investigator prompt plus code-archaeology playbook>",
    output: false
  },
  {
    key: "linear-tickets",
    agent: "pstack.why-linear",
    task: "<filled investigator prompt plus Linear playbook>",
    output: false
  }
]);

const synthesis = await runs.run("synthesizer", {
  agent: "pstack.why-synthesizer",
  task: "<filled synthesizer prompt and epistemics framework>\n\n" +
    "Investigator findings:\n" + findings.map(result => result.output).join("\n\n"),
  output: false
});

return synthesis.output;
```

The example omits `model` so it remains portable. Add only exact models returned by the live registry.

## Step 1. Understand the target

Identify the code, pattern, feature, or design decision under investigation. Common questions include:

- Why was this designed this way?
- Why do we use X instead of Y?
- What edge case motivated this guard?
- What business constraint led to this behavior?
- Why does this code still exist?
- What is the history of this subsystem?

If the target is vague, infer the likely referent from the conversation, recent files, or named symbols. State the interpretation so the user can redirect. Ask only when proceeding could inspect the wrong repository or source scope.

## Step 2. Establish the code anchor

Before launching investigators, anchor the question in concrete source:

- relevant file paths and line ranges
- key symbols
- recent commits touching the target
- PR numbers found in merge or squash commit messages
- linked ticket IDs

Use non-mutating commands only:

```bash
git blame -L <start>,<end> <file>
git log --follow -p -- <file>
git log --oneline -20 -- <file>
git log -1 --format=%B <commit>
gh pr view <number> --json title,body,author,createdAt,mergedAt,labels,closingIssuesReferences,comments,reviews
```

Capture this seed context once and include it in every investigator task.

## Step 3. Build investigator tasks

For each available category, construct one task from:

1. `references/investigator-prompt.md`
2. the matching category playbook from `references/sources/`
3. `references/sources/incident-postmortem.md` when the target looks defensive
4. the code anchor
5. the original question

Every investigator must report:

- source searched
- exact queries and date ranges
- direct evidence with citations and quotations
- indirect evidence with explicit inference chains
- contradictions
- null results and access gaps
- cross-source leads for the parent or another investigator

Investigators collect evidence. They do not write the final answer.

### Source-control investigator

Always launch `pstack.why-git`. It may inspect Git history, `gh pr view`, code comments, tests, ADRs, and changelogs. Its `bash` commands must remain non-mutating.

### Linear investigator

Launch `pstack.why-linear` when Linear is connected and its direct tools are exposed. Use exact direct tool names such as:

- `linear_get_issue`
- `linear_list_issues`
- `linear_list_comments`
- `linear_get_project`
- `linear_list_documents`
- `linear_get_document`

Start with ticket IDs from commits and PRs, then search several keyword variants. Read descriptions, comments, parent issues, projects, and linked Linear documents. Record query text and null results. Do not treat a stale ticket plan as the final implementation rationale without corroboration.

### Missing categories

Skip a category only when:

- no matching MCP is configured or authenticated
- no executable investigator profile exposes that MCP
- the source is provably irrelevant, such as error tracking for a build-time script with no runtime path

Write every skip and reason into the synthesis prompt. "Probably irrelevant" is not enough when the source is available.

## Step 4. Synthesize

After investigators finish, launch `pstack.why-synthesizer` inside the same workflow. Build its task from:

1. all ordered investigator findings, including null results
2. the coverage map and skipped-source reasons
3. the code anchor
4. the original question
5. `references/epistemics.md`
6. `references/synthesizer-prompt.md`

The synthesizer may spot-check source-control and Linear citations using non-mutating tools. It must not search unavailable categories or imply broader coverage than the investigators achieved.

## Step 5. Present

Present the synthesizer output with only light clarity edits. Preserve its confidence labels, hedging, contradictions, and gaps.

Use this structure:

**The question.** Restate the question briefly.

**The code in question.** File paths, line ranges, and symbols.

**What we found.** Direct and supported claims with precise citations.

**What we can reasonably infer.** Hedged claims with visible inference chains.

**Competing hypotheses.** Alternative explanations when the evidence does not select one.

**What we don't know.** Unanswered questions, null searches, unavailable sources, and access limitations.

**Sources consulted.** One line per evidence category, including unavailable and skipped categories. Name the source, searches, results, or skip reason.

**Confidence summary.** State which parts are direct, supported, inferred, speculative, or unknown.

If the investigation precedes a code change, finish with a Preserve / Change / Avoid / Risk constraint set derived from the evidence.

## Failure modes

- Do not turn plausible code reading into confident author intent.
- Do not cite code as proof of its own motivation.
- Do not assume the newest commit contains the original rationale.
- Do not confirm a hypothesis embedded in the user's question without evidence.
- Do not omit categories that returned nothing.
- Do not claim an unavailable MCP was searched.
- Do not collapse several evidence systems into one investigator.
- Do not remove confidence language to make the answer sound firmer.

## Reference files

- `references/epistemics.md`: confidence tiers and phrasing rules
- `references/investigator-prompt.md`: investigator task template
- `references/source-playbook.md`: evidence-category index
- `references/sources/code-archaeology.md`: Git and GitHub history
- `references/sources/linear.md`: Linear tickets, projects, comments, and documents
- `references/sources/notion.md`: long-form documents
- `references/sources/slack.md`: real-time chat
- `references/sources/datadog.md`: infrastructure observability
- `references/sources/sentry.md`: error tracking
- `references/sources/databricks.md`: product analytics warehouse
- `references/sources/incident-postmortem.md`: cross-cutting incident searches
- `references/synthesizer-prompt.md`: final synthesis contract
