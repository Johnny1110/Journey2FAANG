/*
 * @lc app=leetcode id=191 lang=golang
 *
 * [191] Number of 1 Bits
 */

// @lc code=start
func hammingWeight(n int) int {
	cnt := 0

	mapping := 1

	for n > 0 {

		// using mapping
		if n&mapping == 1 {
			cnt++
		}

		n = n >> 1
	}

	return cnt
}

// @lc code=end

