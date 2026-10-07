---
name: investigate
description: Investigate unexpected application behavior using a PostgreSQL read replica and project code. Accept any explicitly named database URL environment variable, including staging or production connections. Trace records, audit history and event processing to the exact code path without changing data.
compatibility: Requires Bash 3.2+, psql, an environment variable containing a PostgreSQL physical replica URL, and the project's source code. No Python, Node or extra packages.
---

# Investigate through a read replica

Explain what happened, which code decided it, and whether it matches the user's expectation. This skill investigates only. Do not fix code, modify records, retry events, enqueue jobs, contact external systems or move money.

## Select the connection

The request supplies an environment variable name and an investigation question:

```text
/skill:investigate PRODUCTION_DB_URL why did record <ID> enter review?
/skill:investigate STAGING_DB_URL why did event <ID> fail?
```

Any valid environment variable name is accepted. There are no project-specific names, default targets or assumptions that a name means a replica. For a request such as `investigate staging`, identify the configured URL variable from existing project instructions or configuration without displaying its value. If it is unclear, ask which variable to use. Do not guess a writer URL or create aliases/configuration without being asked.

Connection setup belongs outside this skill. The selected variable must contain a standard PostgreSQL URL with an explicit user, one network host and database name:

```text
postgresql://reader:<percent-encoded-password>@replica.example.com:5432/app?sslmode=verify-full&sslrootcert=<encoded-CA-path>
```

Prefer a dedicated least-privilege account. A URL may omit the password and use PostgreSQL's protected `~/.pgpass` or `PGPASSFILE`. Keep credentials out of tracked files, arguments, logs and prompts. Never print the selected URL, use shell tracing, dump the environment or pass the URL directly on the `psql` command line.

Resolve `scripts/replica-query.sh` relative to this skill's directory. All database queries must use this helper:

```bash
bash /absolute/path/to/investigate/scripts/replica-query.sh --env PRODUCTION_DB_URL --check
```

The helper reads the named variable without `eval`, decodes connection fields into libpq environment variables and keeps credentials out of process arguments. It supports ordinary PostgreSQL URLs, including percent-encoded credentials and bracketed IPv6 hosts. It rejects unknown connection parameters instead of silently discarding them. Known GUI-only parameters are ignored; provide real libpq TLS settings rather than relying on GUI flags. Multi-host routing and Unix sockets are unsupported so the target remains explicit.

TLS is required. An explicit `sslmode=verify-full` or `verify-ca` is preserved; otherwise the minimum is `require`. Prefer `verify-full` with the approved CA because `require` encrypts but does not reliably authenticate the server. Never weaken TLS to get a result. GSS encryption fallback is disabled. Connection timeouts and application name are fixed by the helper, and startup `options` are unsupported.

Every invocation starts `BEGIN READ ONLY`, sets transaction-local timeouts, and refuses the investigation query unless `pg_is_in_recovery()` is true. A staging URL that points to a primary is refused too. This version supports physical PostgreSQL replicas, not logical replicas or other database engines. Never bypass the check or fall back to a writer. Transaction-local settings avoid PgBouncer's unsupported-startup-parameter errors.

Submit one SELECT or WITH query through stdin:

```bash
bash /absolute/path/to/investigate/scripts/replica-query.sh --env PRODUCTION_DB_URL <<'SQL'
SELECT id, status, created_at, updated_at
FROM relevant_records
WHERE id = '<record ID>'
SQL
```

Omit semicolons. Semicolons and backslashes are rejected; each result is limited to 100 rows and each statement to 15 seconds. These are guardrails, not a SQL authorization system. Submit only reviewed observational SQL. Never invoke mutating functions, administrative/session control functions, remote writes or stored procedures. Read-only transactions do not prevent every function side effect. Do not run application consoles against the database: apparently read-only methods can invoke callbacks or integrations.

## Establish the question

1. Extract record identity and tenant/workspace from the supplied URL or task. Capture observed and expected behavior. Ask only if missing context prevents a targeted investigation.
2. Locate the relevant repository. Use `add_directory` before accessing a project outside the current directory. Follow its instructions and relevant domain/safety documentation.
3. Inspect relevant models, schema, processors and tests before writing SQL. Use `information_schema` when replica columns differ from the checkout. Discover the project's associations, status vocabulary and audit conventions; do not assume a framework or fixed table names.
4. Preserve checkout changes. Do not create repository reports or copy production/customer data into fixtures.

## Build the evidence chain

Start with the exact record, then follow its associations. Verify the tenant matches the URL or task. Scope queries by tenant, source integration, record identity and narrow time windows. Select only necessary columns and JSON fields. Avoid personal profiles, credentials, full clinical notes, payment details or unfiltered response dumps.

1. Read current state, reason, association IDs and relevant timestamps.
2. Read durable audit/status history chronologically, including structured source-decision metadata. Use timestamps with a stable tie-breaker; UUIDs do not establish insertion order. Constrain both type and ID for polymorphic histories and JOINs.
3. Follow parent/child records and the actual assigned provider/integration. Check effective per-provider mappings or overrides, not just defaults.
4. Find the relevant inbound event by source, external identity and time window. Distinguish received, processed and failed. Capture event ID, type, attempts, error and processing time.
5. Check relevant outbound calls, external-identity links and persisted decision facts. Synchronous reads may not leave a call row. Do not invent missing evidence; label reconstructions as inferences if the response was not retained.
6. Inspect sibling records and ownership rules. A complete decision list can approve one item and implicitly deny another. A later event may belong to a different purchase, period or encounter.
7. If financial state matters, inspect it without invoking financial operations. Distinguish authorization, capture, refund and settlement evidence. Parent status alone may not prove payment outcome, and success may be optimistic. Verify amount units instead of guessing.

Keep queries indexed and bounded. No whole-table JSON text searches, total-table counts, broad customer exports or `EXPLAIN ANALYZE`. If the 100-row cap is reached, narrow the scope or paginate using stable timestamp/ID cursors; do not assume the history is complete.

`--check` reports observation time and last replayed transaction timestamp. A quiet replica can have an old replay timestamp without being behind; its age is not measured replication lag. Recent/missing evidence can reflect replication delay. Absence on the replica does not prove an event never occurred.

## Trace the decision in code

- Find the method that writes the observed transition. Follow its conditions and inputs, including ownership, mapping, idempotency, financial gates and state guards.
- Compare the audit with the code branch and tests that specify it. Check canonical documentation and version history when intent is unclear.
- Distinguish a failed job from a successfully applied but unwanted rule. A domain decision can be understood correctly while operational handling deliberately stops at review.
- Keep state vocabularies precise. Related records may use different statuses for the same outcome; do not invent a status or describe one record's state as another's.
- The checkout may differ from deployed code. Say when the diagnosis relies on matching current source to persisted evidence rather than verified deployment identity.
- Comments and old requirements document historical intent, not necessarily current product policy. Separate intent from the user's desired behavior.

## Report and stop

Answer concisely with:

- What happened, exact UTC timestamps and useful record/event identifiers.
- The decisive facts and method/file that caused the transition.
- Whether it was a processing failure, data/configuration problem, deliberate rule or unproven hypothesis.
- The difference between current behavior and expectation, plus missing evidence or replica/deployment uncertainty.
- Confirmation that no application data or code changed.

Do not include unnecessary personal information, raw dumps or secrets. Do not say tests passed unless you ran them. Existing assertions show specified behavior, not proof the suite currently passes.

A requested fix is a separate task. If handing off, load the handoff skill and pass bounded findings, code/test paths, state constraints and safety requirements. Investigation access never authorizes remediation or a historical backfill.
