/*
 * @lc app=leetcode id=198 lang=golang
 *
 * [198] House Robber
 */

// @lc code=start
func rob(nums []int) int {
	if len(nums) == 1 {
		return nums[0]
	}

	prev1, prev2 := 0, 0

	for _, n := range nums {
		prev2, prev1 = prev1, max(prev1, prev2+n)
	}

	return prev1
}

// @lc code=end

