/*
 * @lc app=leetcode id=130 lang=golang
 *
 * [130] Surrounded Regions
 */

// @lc code=start
func solve(board [][]byte) {
	m, n := len(board), len(board[0])
	if m == 0 || n == 0 {
		return
	}

	// init graph state
	safe := make([][]bool, m)
	for i, _ := range safe {
		safe[i] = make([]bool, n)
	}

	directs := [][]int{
		{1, 0}, {-1, 0}, {0, 1}, {0, -1},
	}

	// define dfs
	var dfs func(row, col int)
	dfs = func(row, col int) {
		// check boundry
		if row >= m || row < 0 || col >= n || col < 0 {
			return
		}

		// skip safe area and X area
		if safe[row][col] || board[row][col] == 'X' {
			return
		}

		safe[row][col] = true // mark as safe (reachable from edge)

		for _, dir := range directs {
			dfs(row+dir[0], col+dir[1])
		}
	}

	// dfs start from every edge
	for i := 0; i < m; i++ {
		dfs(i, 0)
		dfs(i, n-1)
	}

	for i := 0; i < n; i++ {
		dfs(0, i)
		dfs(m-1, i)
	}

	for i := 0; i < m; i++ {
		for j := 0; j < n; j++ {
			if board[i][j] == 'O' && !safe[i][j] {
				board[i][j] = 'X'
			}
		}
	}
}

// @lc code=end

