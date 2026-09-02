# 131. Palindrome Partitioning

<br>

---

<br>

## Example

```
Input: s = "aab"
Output: [["a","a","b"],["aa","b"]]
```

<br>
<br>

## Thinking

Instead of asking "what do I do with this character," ask "where does the current piece end."

<br>
<br>

## Coding

```go
func partition(s string) [][]string {
	result := [][]string{}
	currentState := []string{}

	var backtracking func(start int)
	backtracking = func(start int) {
		// base case goes here
		if start == len(s) {
			tmp := make([]string, len(currentState))
			copy(tmp, currentState)
			result = append(result, tmp)
			return
		}

		// loop comes later — leave it out for now
		for end := start; end < len(s); end++ {
			piece := s[start : end+1]
			if isPalindrome(piece) {
				currentState = append(currentState, piece)        // update state
				backtracking(end + 1)                             // dfs
				currentState = currentState[:len(currentState)-1] // fallback state
			}
		}
	}

	backtracking(0) // start from first
	return result
}

func isPalindrome(s string) bool {
	a, b := 0, len(s)-1

	for a < b {
		if s[a] != s[b] {
			return false
		}
		a++
		b--
	}

	return true
}
```

<br>

* 32/32 cases passed (22 ms)
* Your runtime beats 58.37 % of golang submissions
* Your memory usage beats 66.95 % of golang submissions (22.1 MB)

<br>
<br>

## Time and Space Complexity

```
Assume: N = len(s)

Time: O(N · 2^N)
Space: O(N) max call stack is N
```

> Time O(N · 2^N) — 2^(N−1) partitions in the worst case, since with an all-identical string nothing prunes, and O(N) to copy each result. Space O(N) auxiliary for the stack and current path, plus O(N · 2^N) for the output.