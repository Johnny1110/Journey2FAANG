/*
 * @lc app=leetcode id=97 lang=golang
 *
 * [97] Interleaving String
 */

// @lc code=start
func isInterleave(s1 string, s2 string, s3 string) bool {
	if len(s3) != len(s1)+len(s2) {
		return false
	}

	// dynamic-programming
	// define dp dp[i][j] -> from s1[0~i] + from s2(0~j) = s3(0~i+j)
	dp := make([][]bool, len(s1)+1)
	for i := 0; i <= len(s1); i++ {
		dp[i] = make([]bool, len(s2)+1)
	}

	// init dp
	dp[0][0] = true
	for i := 0; i < len(s1); i++ {
		charA, charB := s1[i], s3[i]
		if charA == charB && dp[i][0] {
			dp[i+1][0] = true
		} else {
			break
		}
	}

	for j := 0; j < len(s2); j++ {
		charA, charB := s2[j], s3[j]
		if charA == charB && dp[0][j] {
			dp[0][j+1] = true
		} else {
			break
		}
	}

	for i := 1; i <= len(s1); i++ { // skip 0 (already init)
		for j := 1; j <= len(s2); j++ { // skip 0 (already init)
			s3Char := s3[i+j-1]
			s1Char := s1[i-1]
			s2Char := s2[j-1]

			dp[i][j] = (dp[i-1][j] && s1Char == s3Char) || (dp[i][j-1] && s2Char == s3Char)
		}
	}

	return dp[len(s1)][len(s2)]
}

// @lc code=end

