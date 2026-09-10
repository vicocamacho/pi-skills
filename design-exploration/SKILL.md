---
name: design-exploration
description: Compare alternatives for a novel UI interaction or architectural decision when the repository has no established pattern and multiple materially different choices remain. Do not use for routine implementation, clear bug fixes, or constrained refactors.
---

# Design exploration

1. Confirm that no established repository pattern or constraint already decides the design.
2. State the user-visible or operational outcome and the constraints.
3. Produce two or three genuinely different, cheap sketches or prototypes. Do not build production infrastructure for the comparison.
4. Compare them using concrete criteria such as user effort, failure behavior, migration cost, reversibility, and maintenance load.
5. Ask the user only when the alternatives represent materially different product or architectural choices.
6. Implement the selected option incrementally and remove throwaway prototypes.

Stop exploring once evidence or constraints leave one clear choice.
