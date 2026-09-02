---
name: how
description: "Use for \"how does X work\", code walkthroughs before changing something, and placement / ownership / layering questions (\"where should this live\", \"which package owns this\", \"is this the right layer\"). Explains subsystem architecture, runtime flow, onboarding mental models. Can critique architecture. Use why for motivation."
disable-model-invocation: true
---

# How

Explore the codebase to answer "how does X work?" questions. Produce an architectural explanation suitable for a senior engineer onboarding onto a subsystem. Build a working mental model rather than annotating source code.

Two modes:

1. **Explain** is the default. Explore the codebase and explain it.
2. **Critique** explains the subsystem first, then independently reviews its architecture.

## Pi subagent setup

This skill uses the user-scoped `pstack.how-reader` agent. It has a strict `read`, `grep`, `find`, and `ls` tool allowlist, so exploration cannot modify the repository.

Before launching children:

1. Run `subagent({ action: "list" })` and confirm `pstack.how-reader` is executable.
2. Run `subagent({ action: "models" })` before passing explicit models.
3. Copy exact `provider/id` values from the live registry. Append Pi thinking suffixes such as `:low`, `:xhigh`, or `:max` only when needed.
4. If a preferred model is unavailable, choose a comparable listed model or omit `model` so the child inherits the current default. Never pass an unlisted model ID.

Preferred role mapping when these models are available:

| Role | Preferred model |
| --- | --- |
| Explorer | `openai-codex/gpt-5.6-sol:low` |
| Explainer | `anthropic/claude-fable-5:max` |
| Critics | Up to four distinct listed models, preferably `anthropic/claude-fable-5:max`, `openai-codex/gpt-5.6-sol:max`, `openai-codex/gpt-5.6-terra:xhigh`, and `anthropic/claude-opus-5:xhigh` |

Use one top-level `subagent` call per invocation. Every execution goes through an async `workflowScript`:

- Use `runs.run(key, { agent, task, ... })` for one child.
- Use `runs.all([...])` for parallel explorers or critics.
- Await exploration before launching the explainer.
- In critique mode, await the explanation before launching critics.
- Use stable, descriptive keys.
- `runs.all` returns an ordered array. Read results by index or with `.map(...)`, never by key property.
- Set `context: "fresh"`, `async: true`, and `mission: false` on the top-level call.
- Set `output: false` on children unless a durable artifact was explicitly requested.
- Do not pass `acceptance` for these read-only children.
- Do not use `async: false`. In an interactive session, return control and let Pi wake the session on completion. If the answer must be produced in the current turn, use `subagent_wait` for the async run.

The workflow sandbox cannot read prompt files. The parent must read the relevant templates from `references/`, fill their placeholders, JSON-encode the completed strings, and interpolate them into `workflowScript` task fields before launch.

## Explain mode

### Step 1. Understand the question and assess complexity

Parse what the user is asking about:

- "How does the rate limiter work?" asks about a subsystem.
- "How do we handle billing for on-demand usage?" asks about a feature flow.
- "How is the auth service structured?" asks for an architectural overview.
- "Walk me through what happens when a user submits a form" asks for a runtime trace.

Identify the scope. If it is ambiguous, state your best-guess interpretation before exploring. Do not stop to ask unless proceeding could inspect the wrong repository or expose information outside the user's intended scope. Let the user redirect if the interpretation is off.

Choose the workflow:

- **Simple:** a single module, a small utility, or a narrow question such as "how does function X work?" Use one direct explainer child.
- **Complex:** a subsystem spanning several files or services, a cross-cutting feature, or a broad architectural overview. Use parallel explorers followed by one explainer.

When in doubt, lean simple.

### Step 2a. Explore complex questions

Split the question into two to four distinct exploration angles. For example:

- data model and state management
- request path and enforcement
- configuration and metrics

Each child uses:

- `agent: "pstack.how-reader"`
- the selected explorer model when available
- `references/explorer-prompt.md`, filled with the original question and one distinct angle
- a stable key such as `explorer-data` or `explorer-request-flow`
- `output: false`

Launch all explorers with one `runs.all([...])`. Do not send clone prompts whose only difference is a number. Each angle must name a distinct source seam and investigation goal.

### Step 2b. Explain simple questions directly

Read `references/explainer-prompt.md` and adapt it for direct exploration by replacing the explorer-findings section with a clear statement that no prior explorer findings exist and the child must inspect the named source seam itself.

Launch one child with `runs.run("direct-explainer", ...)` using `pstack.how-reader` and the selected explainer model.

### Step 3. Synthesize complex questions

After `runs.all` returns, build the explainer task from:

1. the original question
2. every ordered explorer result
3. `references/explainer-prompt.md`

Launch `runs.run("explainer", ...)` inside the same `workflowScript`. The explainer reconciles overlap, checks contradictions against the code, and produces the human-facing explanation.

The coordinated workflow has this shape:

```javascript
const findings = await runs.all([
  {
    key: "explorer-flow",
    agent: "pstack.how-reader",
    task: "<filled explorer prompt for request flow>",
    output: false
  },
  {
    key: "explorer-data",
    agent: "pstack.how-reader",
    task: "<filled explorer prompt for data and state>",
    output: false
  }
]);

const explanation = await runs.run("explainer", {
  agent: "pstack.how-reader",
  task: "<filled explainer prompt>\n\nExplorer findings:\n" +
    findings.map(result => result.output).join("\n\n"),
  output: false
});

return explanation.output;
```

The example omits `model` so it remains portable. Add only exact models returned by the live registry.

### Step 4. Present

Present the explainer output. Light editing for clarity is fine, but preserve technical claims, uncertainty, and source references.

## Explanation output

Adapt this structure to the question. Omit sections that add no value.

**Overview.** One or two paragraphs explaining what the subsystem is, what it does, and why it exists.

**Key concepts.** Brief definitions of the types, services, and abstractions needed to follow the rest.

**How it works.** Walk through the trigger, execution flow, data movement, and decision points. Reference specific files and functions. Use prose rather than pseudocode. Include a diagram only when it makes a multi-component flow easier to understand.

**Where things live.** Map the few files and directories someone should open first.

**Gotchas.** Call out surprising behavior, sharp edges, unresolved gaps, and historical artifacts that a newcomer could misunderstand.

## Critique mode

Use critique mode when the user asks for architectural problems or improvements, not merely an explanation.

### Step 1. Explain first

Run the simple or complex explain path inside the workflow. The architecture must be understood before it is judged.

### Step 2. Run independent critics

Read `references/critic-prompt.md` and `references/critique-rubric.md`. Build one critic task per selected model. Every critic receives:

1. the completed explanation
2. the relevant file paths
3. the full critique rubric

Launch two to four critics with one `runs.all([...])` after the explainer completes. Use `pstack.how-reader`, distinct keys, `output: false`, and distinct available model families where possible. If only one suitable model is available, two independent runs on that model are acceptable, but disclose the reduced model diversity.

Return both the explanation and ordered critic outputs from the same workflow:

```javascript
return {
  explanation: explanation.output,
  critics: critics.map(result => result.output)
};
```

Use Council Mode instead of this critic fanout when the user asks advisors to debate a material design decision, cross-examine recommendations, or reach a decision. Ordinary code-health critique remains a parallel read-only review.

### Step 3. Lead judgment

The parent is the decision-maker, not an aggregator. Check each finding against the code and classify it:

- **Act on.** A demonstrated architectural problem worth fixing now.
- **Consider.** A real concern whose cost or benefit remains unclear.
- **Noted.** A valid low-priority observation.
- **Dismissed.** Incorrect, missing context, or merely a style preference.

Present the explanation first, then the critique verdict. The explanation must stand on its own.
