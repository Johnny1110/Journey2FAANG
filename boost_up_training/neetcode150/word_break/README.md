# 139. Word Break

<br>

---

<br>

## Think

```go
dp := make([]bool, len(s)+1)
// dp[i] = can s[0:i] (the first i characters) be segmented?
```

## Coding

```go
func wordBreak(s string, wordDict []string) bool {
	// 1. init wordMap
	wordMap := make(map[string]bool)
	for _, word := range wordDict {
		wordMap[word] = true
	}

	// 2. init dp
	dp := make([]bool, len(s)+1)
	dp[0] = true // for everytime valid segment check must start from index 0

	for i := 1; i <= len(s); i++ {

		for j := 0; j <= i; j++ {
			if !dp[j] {
				continue // only last valid segment position
			}

			word := s[j:i]
			if wordMap[word] {
				dp[i] = true
				break
			}
		}
	}

	return dp[len(s)]
}
```

* 49/49 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 78.24 % of golang submissions (4 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = Len of s

Time: O(N square) 2 nested loop
Space: O(N) -> 1D dp
```