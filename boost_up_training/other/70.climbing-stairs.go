/*
 * @lc app=leetcode id=70 lang=golang
 *
 * [70] Climbing Stairs
 */

// @lc code=start
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

// @lc code=end

