# Feedback: 76. Minimum Window Substring

## Score: 7 / 10

---

## What's Good

- **Algorithm correctness**: The sliding-window logic is correct. Left shrinks when the window is valid, right expands to find more characters. The `needT` map tracks remaining/excess counts properly, and the `need` counter gates the shrink phase.
- **Time & Space Complexity**: Both are correct — O(m) time (each character visited at most twice) and O(n) space for the map.

## What Needs Improvement

### 1. Code structure is harder to follow than necessary

The `for right < len(s) || shrinkFlag` loop combined with the `shrinkFlag` boolean creates a state machine that's not intuitive. A cleaner pattern separates expand and shrink into two explicit phases:

```go
for right < len(s) {
    // expand: always advance right
    // ...

    // shrink: contract left while window is valid
    for need == 0 {
        // update best
        // remove s[left] from window
        left++
    }
}
```

This is the standard sliding-window template and is much easier to reason about.

### 2. `need` variable becomes semantically misleading

During the shrink phase, when `needT[letter]++` crosses from 0 to 1, `need` is NOT incremented. This means `need` stays at 0 even though characters have been removed from the window. It doesn't cause a bug because `shrinkFlag` gates the shrink loop, but a reader would expect `need` to stay in sync with what's actually needed.

### 3. Sentry-value pattern is fragile

`best := []int{0, 0}` with the check `best[1] == 0` as "not yet updated" is a sentinel pattern. While it works here (a valid window can never end at index 0), it would confuse an interviewer. Prefer an explicit sentinel:

```go
bestLen := math.MaxInt32
bestStart := 0
```

### 4. Best-update is placed confusingly inside the shrink loop

The best-window check runs on every shrink iteration, including the one where `shrinkFlag = false` is set (which will be the last iteration). The window at that point IS valid, so the result is correct, but the placement makes it look like a potential bug — you're recording a "best" on what's about to become an invalid or unchanged window state.

In the standard template, the best update happens **before** contracting left, making intent crystal clear:

```go
for need == 0 {
    if right-left < bestLen {
        bestLen = right - left
        bestStart = left
    }
    // then contract...
}
```

## Hint for Improvement

Try rewriting this using the standard sliding-window template (expand loop + inner shrink loop). The logic is the same, but the structure is cleaner and interviewers expect to see it. It also naturally eliminates the `shrinkFlag` boolean and the confusing `best` sentinel.
