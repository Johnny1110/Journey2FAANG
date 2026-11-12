/*
 * @lc app=leetcode id=695 lang=golang
 *
 * [695] Max Area of Island
 */

// @lc code=start
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

// @lc code=end

