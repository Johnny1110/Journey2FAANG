/*
 * @lc app=leetcode id=74 lang=golang
 *
 * [74] Search a 2D Matrix
 */

// @lc code=start
func searchMatrix(matrix [][]int, target int) bool {
	m, n := len(matrix), len(matrix[0])
	left, right := 0, m*n-1
	for left <= right {
		mid := (left + right) / 2
		val := matrix[mid/n][mid%n]
		if val == target {
			return true
		} else if val > target {
			right = mid - 1
		} else {
			left = mid + 1
		}
	}
	return false
}

// @lc code=end

