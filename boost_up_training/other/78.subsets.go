/*
 * @lc app=leetcode id=78 lang=golang
 *
 * [78] Subsets
 */

// @lc code=start
func subsets(nums []int) [][]int {
	result := [][]int{}
	state := make([]int, 0, len(nums))

	var backtracking func(idx int)
	backtracking = func(idx int) {

		// update result
		tmp := make([]int, len(state))
		copy(tmp, state)
		result = append(result, tmp)

		// backtracking
		for i := idx; i < len(nums); i++ {
			state = append(state, nums[i])
			// go deeper
			backtracking(i + 1)
			// rollback
			state = state[:len(state)-1]
		}

	}
	backtracking(0)

	return result
}

// Input: nums = [1,2,3]
// Output: [[],[1],[2],[1,2],[3],[1,3],[2,3],[1,2,3]]
// @lc code=end

