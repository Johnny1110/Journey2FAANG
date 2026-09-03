/*
 * @lc app=leetcode id=134 lang=golang
 *
 * [134] Gas Station
 */

// @lc code=start
func canCompleteCircuit(gas []int, cost []int) int {
	n := len(gas)
	start := 0

	for start < n {
		tank, i, step := 0, start, 0

		for step < n {
			tank += gas[i] - cost[i] // fillin: +gas[i]  payout: -cost[i]
			if tank < 0 {
				break
			}

			i = (i + 1) % n
			step++
		}

		if step == n {
			return start
		}

		if i < start {
			return -1 // stop
		}

		start = i + 1 // every start in [start, i] is invalid
	}
	return -1
}

// @lc code=end

