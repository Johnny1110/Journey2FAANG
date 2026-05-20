/*
 * @lc app=leetcode id=73 lang=golang
 *
 * [73] Set Matrix Zeroes
 */

// @lc code=start
func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		for i := 0; i < len(matrix); i++ {
			matrix[i][col] = 0
		}
		for i := 0; i < len(matrix[row]); i++ {
			matrix[row][i] = 0
		}
	}
}

// @lc code=end

