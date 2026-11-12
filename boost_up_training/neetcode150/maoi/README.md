# 695. Max Area of Island

<br>

---

<br>

## Desc

You are given an `m x n` binary matrix grid. An island is a group of 1's (representing land) connected 4-directionally (horizontal or vertical.) You may assume all four edges of the grid are surrounded by water.

The area of an island is the number of cells with a value 1 in the island.

Return the maximum area of an island in grid. If there is no island, return 0.

<br>
<br>

## Coding

```go
func maxAreaOfIsland(grid [][]int) int {
	// dfs
	maxResult := 0
	n, m := len(grid), len(grid[0])

	directions := [][]int{{0, 1}, {1, 0}, {0, -1}, {-1, 0}}

	// explore 1 direction, and return explored area
	var dfs func(row, col int) int
	dfs = func(row, col int) int {
		// check boundary
		if row < 0 || row >= n || col < 0 || col >= m {
			return 0 // out of bound
		}
		// check island
		if grid[row][col] == 0 {
			return 0
		} else {
			// mark this slot has been visited
			grid[row][col] = 0
		}

		area := 1
		// explore 4 direction
		for _, dir := range directions {
			area += dfs(row+dir[0], col+dir[1])
		}

		return area
	}

	for i := 0; i < n; i++ {
		for j := 0; j < m; j++ {
			if grid[i][j] == 1 {
				maxResult = max(maxResult, dfs(i, j))
			}
		}
	}

	return maxResult
}
```

* 728/728 cases passed (2 ms)
* Your runtime beats 44.02 % of golang submissions
* Your memory usage beats 22.22 % of golang submissions (7 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: n = rows, m = cols, k = maxIsland

Time : O(n*m)
Space: O(k)
```