/*
 * @lc app=leetcode id=202 lang=golang
 *
 * [202] Happy Number
 */

// @lc code=start
func isHappy(n int) bool {
	// cycle detect algo
	next := func(x int) int {
		sum := 0
		for x > 0 {
			a := x % 10
			x = x / 10
			sum += a * a
		}
		return sum
	}

	slow, fast := n, next(n)

	for fast != 1 && slow != fast {
		slow, fast = next(slow), next(next(fast))
	}

	return fast == 1
}

// @lc code=end

