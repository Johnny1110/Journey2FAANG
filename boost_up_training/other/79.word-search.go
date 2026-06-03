/*
 * @lc app=leetcode id=79 lang=golang
 *
 * [79] Word Search
 */

// @lc code=start
func exist(board [][]byte, word string) bool {
	m, n := len(board), len(board[0])

	// dfs directions
	directions := [][]int{
		{1, 0},  // down
		{-1, 0}, // up
		{0, 1},  // right
		{0, -1}, // left
	}

	var dfs func(row, col, widx int) bool
	dfs = func(row, col, widx int) bool {
		targetLetter := word[widx]
		thisLetter := board[row][col]

		if targetLetter != thisLetter {
			return false
		}

		if widx == len(word)-1 {
			return true
		}

		board[row][col] = '#'

		for _, dir := range directions {
			nextRow, nextCol := row+dir[0], col+dir[1]
			if nextRow < 0 || nextRow >= m || nextCol < 0 || nextCol >= n || board[nextRow][nextCol] == '#' {
				continue
			}

			if dfs(nextRow, nextCol, widx+1) {
				return true
			}
		}

		// rollback visited
		board[row][col] = thisLetter
		return false
	}

	for i := 0; i < m; i++ {
		for j := 0; j < n; j++ {
			if dfs(i, j, 0) {
				return true
			}
		}
	}

	return false
}

// A B C E
// S F C S
// A D E E
// @lc code=end

