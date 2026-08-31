/*
 * @lc app=leetcode id=128 lang=golang
 *
 * [128] Longest Consecutive Sequence
 */

// @lc code=start
func longestConsecutive(nums []int) int {
	if len(nums) == 0 {
		return 0
	}

	hs := make(map[int]int8)
	for _, n := range nums {
		hs[n] = 1
	}

	best := 0
	// 6
	for n := range hs {

		if hs[n-1] != 1 { // only from start
			temp := 1
			n++              // try to find next
			for hs[n] == 1 { // found next
				n++
				temp++
			}

			best = max(best, temp)
		}
	}

	return best
}

// @lc code=end

