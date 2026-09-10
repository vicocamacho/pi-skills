---
name: mechanical-migrations
description: Handle repetitive or high-risk changes across many files, records, schemas, or callers. Use for codemods, bulk edits, data migrations, and coordinated internal API replacement. Do not use for a few obvious edits.
---

# Mechanical migrations

1. Inventory the affected files, records, callers, and contracts.
2. Change one representative unit manually to learn the exact transformation.
3. Build the smallest deterministic script only when it improves consistency or makes the work rerunnable and reviewable.
4. Make the script safe to rerun. Provide a dry run or bounded preview when it mutates persistent data.
5. Apply and verify the migration in small units so failures are attributable to one change.
6. Inspect the generated diff or transformed data. Do not trust the script's exit status alone.
7. When replacing an internal API, migrate known callers and remove the old path in the same planned change unless an external contract or rollout requires compatibility.
8. Keep the script only when the migration or its verification must outlive the session.
