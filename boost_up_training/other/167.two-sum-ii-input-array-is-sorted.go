/*
 * @lc app=leetcode id=167 lang=golang
 *
 * [167] Two Sum II - Input Array Is Sorted
 */

// @lc code=start
func twoSum(numbers []int, target int) []int {
	left, right := 0, len(numbers)-1
	for left < right {
		sum := numbers[left] + numbers[right]

		if sum == target {
			return []int{left + 1, right + 1}
		} else if sum > target {
			// need a smaller sum
			right--
		} else {
			// need a bigger sum
			left++
		}
	}

	return []int{}
}

// @lc code=end

