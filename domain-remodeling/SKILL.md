---
name: domain-remodeling
description: Reconsider a domain model when branches or shape assumptions repeat across files, persisted values must stay synchronized, ownership is unclear, or a defect demonstrates an invalid state. Do not use merely to make local code more abstract.
---

# Domain remodeling

1. Name the domain facts, valid states, transitions, ownership, and access patterns before choosing a structure.
2. Identify the duplicated rules, synchronized values, invalid combinations, or unclear ownership the redesign must remove.
3. Prefer one authoritative representation. Derive secondary facts rather than storing values that must remain synchronized.
4. Choose the smallest structure that makes the rules clear. A model, constrained value, lookup table, association, or state machine is justified only when it removes concrete branching, duplication, or invalid states.
5. Account for persisted data, callers, public contracts, and migration safety before changing representation.
6. Test allowed transitions and previously invalid combinations through observable behavior.

Keep direct local code when the current shape is clear and the proposed abstraction would only add indirection.
