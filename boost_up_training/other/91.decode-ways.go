/*
 * @lc app=leetcode id=91 lang=golang
 *
 * [91] Decode Ways
 */

// @lc code=start
func numDecodings(s string) int {
	if s == "" {
		return 0
	}

	if s[0] == '0' {
		return 0
	}

	// define dp count from s[0]~s[i]
	dp := make([]int, len(s)+1)
	// init 0, 1
	dp[0] = 1
	dp[1] = 1

	// 11106
	for i := 2; i <= len(s); i++ {
		prev, curr := s[i-2], s[i-1]
		// one char
		if curr != '0' {
			dp[i] += dp[i-1]
		}

		// two char
		two := (prev-'0')*10 + (curr - '0')
		if two >= 10 && two <= 26 {
			dp[i] += dp[i-2]
		}
	}

	return dp[len(s)]
}

// @lc code=end

