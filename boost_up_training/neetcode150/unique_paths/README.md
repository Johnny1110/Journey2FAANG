# 62. Unique Paths

<br>

---

<br>

## Coding

```go
func uniquePaths(m int, n int) int {
	// m: ----
	// n: |

	if n <= 1 || m <= 1 {
		return 1
	}

	// init DP
	dp := make([]int, m)
	for i := 0; i < m; i++ {
		dp[i] = 1
	}

	for i := 1; i < n; i++ {
		for j := 1; j < m; j++ {
			dp[j] = dp[j-1] + dp[j]
		}
	}

	return dp[m-1]
}
```

<br>
<br>

## Time & Space Complexity

```
Time: O(m*n) iterate through all slots.

Space: O(m) need a 1D array as DP, length is m
```