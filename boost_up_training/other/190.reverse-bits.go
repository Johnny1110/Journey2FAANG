/*
 * @lc app=leetcode id=190 lang=golang
 *
 * [190] Reverse Bits
 */

// @lc code=start
func reverseBits(n int) int {
	val := 0

	for i := 31; i >= 0; i-- {
		a := n / (1 << i)
		if a == 1 {
			x := 31 - i
			val += (1 << x)
		}

		n = n % (1 << i)
	}
	return val
}

// @lc code=end

