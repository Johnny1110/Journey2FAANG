package surroundedregions

func solve(board [][]byte) {

	targets := [][]int{}
	for i := 0; i < len(board); i++ {
		for j := 0; j < len(board[i]); j++ {
			if board[i][j] == 'O' {
				targets = append(targets, []int{i, j})
			}
		}
	}

	// init graphState -> true is visited
	graphState := make([][]bool, len(board))
	for i, _ := range graphState {
		graphState[i] = make([]bool, len(board[0]))
	}

	// 4 directions
	direct := [][]int{
		[]int{1, 0}, []int{-1, 0}, []int{0, 1}, []int{0, -1},
	}

	// dfs
	var dfs func(row, col int) bool
	dfs = func(row, col int) bool {

		graphState[row][col] = true // mark as visited.

		val := board[row][col]
		if val == 'X' {
			return false
		}

		// if val is 'O', try explore 4 direction.
		for _, dir := range direct {
			nextRow, nextCol := row+dir[0], col+dir[1]
			// check boundary
			if nextRow > len(board) || nextRow < 0 || nextCol > len(board[0]) || nextCol < 0 {
				return true // 'O' at boundry.
			}

			exploreResult := dfs(nextRow, nextCol)
			if exploreResult {
				return true
			}
		}

		return false
	}

	for _, t := range targets {
		if dfs(t[0], t[1]) {
			board[t[0]][t[1]] = 'X'
		}
	}
}
