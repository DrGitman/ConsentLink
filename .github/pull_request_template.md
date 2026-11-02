## What and why

<!-- One or two sentences. Link the issue: "Closes #12". -->

Closes #

Figma frame: <!-- e.g. 04.3, or "none" for non-UI changes -->

## Definition of done

- [ ] Matches its Figma frame (number: ___)
- [ ] Works in airplane mode, or says why it can't: ___
- [ ] Every control has a screen-reader label
- [ ] No hard-coded text: strings are in the localisation file (`app/l10n/`)
- [ ] Tests added or updated
- [ ] Reviewed (1 approval) and CI green

## The 11 design rules (UX laws)

<!-- For changes with no screen, tick "No UI in this PR" and skip the rest. -->

- [ ] No UI in this PR
- [ ] **Hick:** at most 1 primary + 2 secondary actions
- [ ] **Fitts:** targets ≥ 48 dp, primary action at the bottom
- [ ] **Jakob:** platform patterns used
- [ ] **Miller:** ≤ 7 items per group
- [ ] **Peak-End:** the flow ends on a success screen
- [ ] **Aesthetic:** 8 dp grid, library components only
- [ ] **Hierarchy:** one headline, key item largest
- [ ] **Consistency:** same word, icon and position for the same action
- [ ] **Accessibility:** contrast ≥ 4.5:1, works at 200% text, labels present
- [ ] **Feedback:** response < 100 ms, progress shown for waits
- [ ] **User control:** back / undo / confirm destructive actions
