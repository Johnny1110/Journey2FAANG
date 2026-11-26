# 200. Number of Islands

<br>

---

<br>

## Coding

```go
func numIslands(grid [][]byte) int {
	n, m := len(grid), len(grid[0])
	directs := [][]int{{1, 0}, {0, 1}, {-1, 0}, {0, -1}}

	var dfs func(row, col int)
	dfs = func(row, col int) {
		if row < 0 || row >= n || col < 0 || col >= m || grid[row][col] != '1' {
			// out bound or water
			return
		}

		// remove 1
		grid[row][col] = '0'

		// explore 4 dirs
		for _, dir := range directs {
			dfs(row+dir[0], col+dir[1])
		}
	}

	landCnt := 0
	for i := 0; i < n; i++ {
		for j := 0; j < m; j++ {
			if grid[i][j] == '1' {
				landCnt++
				dfs(i, j)
			}
		}
	}

	return landCnt
}
```

* 49/49 cases passed (3 ms)
* Your runtime beats 87.92 % of golang submissions
* Your memory usage beats 38.77 % of golang submissions (6.5 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: n, m := len(grid), len(grid[0]), k = max iland size

Time: O(n*m)
Space: O(k)
```