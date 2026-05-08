/*
 * @lc app=leetcode id=72 lang=golang
 *
 * [72] Edit Distance
 */

// @lc code=start
func minDistance(word1 string, word2 string) int {
	// define dp: dp[i][j] = from word1[i] to word2[j] need how many step
	dp := make([][]int, len(word1)+1)
	for i := 0; i <= len(word1); i++ {
		dp[i] = make([]int, len(word2)+1)
	}

	// init dp:
	// from empty to word2[0] ~ word2[n] -> add every times
	for j := 1; j <= len(word2); j++ {
		dp[0][j] = j
	}

	//  from word1[0] ~ word1[n] to empty -> remove every times
	for i := 0; i <= len(word1); i++ {
		dp[i][0] = i
	}

	for i := 1; i <= len(word1); i++ {
		for j := 1; j <= len(word2); j++ {

			c1, c2 := word1[i-1], word2[j-1]
			if c1 == c2 {
				dp[i][j] = dp[i-1][j-1]
			} else {
				// replace:
				a := dp[i-1][j-1] + 1
				// add:
				b := dp[i][j-1] + 1
				// remove:
				c := dp[i-1][j] + 1

				dp[i][j] = min(a, b, c)
			}
		}
	}

	return dp[len(word1)][len(word2)]
}

// Input: word1 = "horse", word2 = "ros"
// Output: 3
// Explanation:
// horse -> rorse (replace 'h' with 'r')
// rorse -> rose (remove 'r')
// rose -> ros (remove 'e')
// @lc code=end

