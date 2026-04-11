---
name: code-review
description: Code review checklist and standards for Math Buddy — React Native (Expo), AWS Lambda, and DynamoDB.
---

# Code Review

Structured checklist for reviewing changes in this codebase. Work through each section relevant to the files changed.

## When to Activate

- Before merging any branch or PR
- After completing a feature or bug fix
- When asked to review a file or diff

---

## 1. Correctness

- [ ] Does the code do what it claims to do?
- [ ] Are edge cases handled (empty input, zero, null, network failure)?
- [ ] Are all code paths reachable and correct?
- [ ] No off-by-one errors in loops or array access?

---

## 2. Tests

- [ ] New logic has corresponding unit tests
- [ ] **Every test has at least one `expect()` with a meaningful assertion** — no empty tests, no tests that only check "no crash"
- [ ] Assertions check specific values, not just truthiness — prefer `toBe(1)` over `toBeTruthy()`
- [ ] Callback mocks assert call count AND arguments where relevant — e.g. `toHaveBeenCalledWith(...)`
- [ ] Negative assertions present where applicable — e.g. `expect(onWrong).not.toHaveBeenCalled()`
- [ ] Timer-driven or animation-driven updates wrapped in `act()`
- [ ] No test depends on another test's state (`beforeEach` resets properly)
- [ ] `jest.fn()` mocks cleared after each test

---

## 3. React Native Components

- [ ] No missing `key` props on lists
- [ ] `useEffect` has correct dependency array — no stale closures
- [ ] Animated values do not mix `useNativeDriver: true` and `false`
- [ ] Touch targets are at least 48×48dp
- [ ] `testID` added to every interactive or meaningful UI element (see coding-standards skill)
- [ ] `accessibilityLabel` and `accessibilityRole` on all touch targets
- [ ] No inline styles that should be `StyleSheet.create`

---

## 4. Game Mode Components

- [ ] Component accepts `{ question, onCorrect, onWrong }` props — no extras required
- [ ] `onCorrect` / `onWrong` called exactly once per interaction (no double-fire)
- [ ] Game loop / animation cleaned up on unmount (`useEffect` return / `phaseRef`)
- [ ] `question` prop change resets all local state correctly

---

## 5. AWS Lambda (`lambda/mathBuddy.mjs`)

- [ ] Input validated before touching DynamoDB (userId, playerName, score types + ranges)
- [ ] DynamoDB errors caught and logged with `console.error`
- [ ] Successful operations logged with `console.log` (visible in CloudWatch)
- [ ] No AWS credentials, secrets, or account IDs hardcoded
- [ ] Response always includes `Content-Type: application/json` and `Access-Control-Allow-Origin: *`
- [ ] After any change: run `npm run deploy:lambda` or push to `master` to trigger CI deploy

---

## 6. API / Services (`services/scoresApi.js`)

- [ ] All API calls have a timeout (currently 8s via `AbortController`)
- [ ] Failures return `null` — never throw to the caller
- [ ] No secrets or keys in client-side code
- [ ] `EXPO_PUBLIC_` prefix used for any env vars exposed to the app

---

## 7. Security

- [ ] No user-supplied strings interpolated into DynamoDB expressions (use `ExpressionAttributeValues`)
- [ ] No `.env` or credential files staged for commit (`.gitignore` covers `.env`)
- [ ] Player name length enforced both client-side and in Lambda validation
- [ ] Score is validated as a non-negative integer in Lambda before writing

---

## 8. Code Quality (KISS / DRY / YAGNI)

- [ ] No dead code or commented-out blocks left behind
- [ ] No abstraction added for a single use case
- [ ] Variable and function names are clear without needing a comment
- [ ] No `console.log` debug statements left in React Native components
- [ ] No logic duplicated across files — if the same algorithm or helper appears in more than one place, extract it to `utils/` and import it
- [ ] Test files do not contain inline copies of production logic unless a framework constraint (e.g. Three.js/R3F) prevents importing the real module — in that case, note the constraint in a comment

---

## 9. Final Checks

- [ ] `npm test -- --watchAll=false` passes with no warnings
- [ ] No new `act()` violations (setup in `jest.setup.js` will fail the test if present)
- [ ] Lambda deployed after any changes to `lambda/mathBuddy.mjs`
- [ ] `.env` is gitignored and not staged
