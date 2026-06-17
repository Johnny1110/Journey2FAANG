/*
 * @lc app=leetcode id=90 lang=golang
 *
 * [90] Subsets II
 */

// @lc code=start
func subsetsWithDup(nums []int) [][]int {
	sort.Ints(nums)

	result := [][]int{}
	state := make([]int, 0, len(nums))

	var backtracking func(idx int)
	backtracking = func(idx int) {
		tmp := make([]int, len(state))
		copy(tmp, state)
		result = append(result, tmp)

		for i := idx; i < len(nums); i++ {
			// decup
			if i > idx && nums[i] == nums[i-1] {
				continue
			}
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

// [[],[1],[1,2],[1,2,2],[1,2],[2],[2,2],[2]]

// Input: nums = [1,2,2]
// Output: [[],[1],[1,2],[1,2,2],[2],[2,2]]
// @lc code=end

