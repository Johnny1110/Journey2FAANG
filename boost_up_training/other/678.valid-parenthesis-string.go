/*
 * @lc app=leetcode id=678 lang=golang
 *
 * [678] Valid Parenthesis String
 */

// @lc code=start
func checkValidString(s string) bool {
	// tracking open count range
	min, max := 0, 0

	for _, char := range s {
		if char == '(' {
			// open
			min++
			max++
		} else if char == ')' {
			// close
			if min > 0 {
				min--
			}
			max--

			if max < 0 {
				return false // can not accept )
			}

		} else {
			// wildcard
			if min > 0 {
				min--
			}
			max++
		}
	}

	return min == 0
}

// @lc code=end

