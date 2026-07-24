/*
 * @lc app=leetcode id=1046 lang=golang
 *
 * [1046] Last Stone Weight
 */

// @lc code=start
func lastStoneWeight(stones []int) int {
	if len(stones) == 1 {
		return stones[0]
	}

	// 1. sort stones
	slices.SortFunc(stones, func(a, b int) int { return cmp.Compare(b, a) })

	x := 1
	for y := 0; y < len(stones); y++ {
		weightX, weightY := stones[x], stones[y]
		remainingWeight := weightY - weightX

		// replace x position
		stones[x] = remainingWeight

		if remainingWeight > 0 {
			// bubble sort:
			for i := x + 1; i < len(stones); i++ {
				if stones[i-1] < stones[i] {
					tmp := stones[i]
					stones[i] = stones[i-1]
					stones[i-1] = tmp
				} else {
					break
				}
			}
		}

		if remainingWeight == 0 {
			x++
			y++
		}

		x++

		if x >= len(stones) {
			break
		}
	}

	return stones[len(stones)-1]
}

// @lc code=end

