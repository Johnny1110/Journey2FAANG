/*
 * @lc app=leetcode id=153 lang=golang
 *
 * [153] Find Minimum in Rotated Sorted Array
 */

// @lc code=start
func findMin(nums []int) int {
	// find out reverse point?

	left, right, mid := 0, len(nums)-1, 0

	for left < right {
		// mid = left + (right-left)/2
		mid = (left + right) / 2
		midVal, rightVal := nums[mid], nums[right]

		if midVal > rightVal {
			// target "min" is on right side (after curr mid)
			left = mid + 1
		} else {
			right = mid
		}
	}

	return nums[left]
}

// @lc code=end

