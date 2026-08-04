/*
 * @lc app=leetcode id=115 lang=golang
 *
 * [115] Distinct Subsequences
 */

// @lc code=start
func numDistinct(s string, t string) int {
	// define dp:
	// i: from 0 chars to i chars of string s
	// j: from 0 chars to j chars of string t
	// value: the possible way to transfer from s[0:i-1] to t[0:j-1]
	dp := make([][]int, len(s)+1)
	for i := 0; i <= len(s); i++ {
		dp[i] = make([]int, len(t)+1)
		// dp[i][0] = 1 -> all string s become to empty have 1 way, adapt nothing.
		dp[i][0] = 1
	}
	// empty -> empty = 1
	dp[0][0] = 1

	// fill-in the DP
	for i := 1; i <= len(s); i++ {
		for j := 1; j <= len(t); j++ {
			// i chars from s
			// j chars from t

			dp[i][j] = dp[i-1][j] // skip s[i-1]

			if s[i-1] == t[j-1] {
				// both chars are the same
				dp[i][j] += dp[i-1][j-1]
			}
		}
	}

	return dp[len(s)][len(t)]
}

// @lc code=end

