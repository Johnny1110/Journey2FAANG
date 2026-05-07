# 70. Climbing Stairs

<br>

---

<br>

## Coding - Standard DP

```go
func climbStairs(n int) int {
	if n < 2 {
		return 1
	}

	dp := make([]int, n)
	// init dp
	dp[0] = 1
	dp[1] = 2

	for i := 2; i < n; i++ {
		dp[i] = dp[i-1] + dp[i-2]
	}

	return dp[n-1]
}
```

<br>

### Refine Space

```go
func climbStairs(n int) int {
	if n < 2 {
		return 1
	}

	// init dp
	A, B := 1, 2

	for i := 2; i < n; i++ {
		tmp := A + B
		A = B
		B = tmp
	}

	return B
}
```

## Time & Space Complexity

```
Time: O(n)

Space: O(1) -> A + B + tmp
```