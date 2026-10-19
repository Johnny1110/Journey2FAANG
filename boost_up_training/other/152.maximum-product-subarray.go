/*
 * @lc app=leetcode id=152 lang=golang
 *
 * [152] Maximum Product Subarray
 */

// @lc code=start
func maxProduct(nums []int) int {
	n := len(nums)
	// define dp[i] -> max product include nums[i]
	dpMax := make([]int, n)
	dpMin := make([]int, n)
	dpMax[0], dpMin[0] = nums[0], nums[0]

	answer := nums[0]
	for i := 1; i < n; i++ {
		currNum := nums[i]
		dpMax[i] = max(dpMax[i-1]*currNum, dpMin[i-1]*currNum, currNum)
		dpMin[i] = min(dpMax[i-1]*currNum, dpMin[i-1]*currNum, currNum)

		answer = max(answer, dpMax[i])
	}

	return answer
}

// @lc code=end

