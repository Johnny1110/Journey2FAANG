/*
 * @lc app=leetcode id=139 lang=golang
 *
 * [139] Word Break
 */

// @lc code=start
// Input: s = "applepenapple", wordDict = ["apple","pen"]
// Input: s = "leetcode", wordDict = ["leet","code"]
func wordBreak(s string, wordDict []string) bool {
	// 1. init wordMap
	wordMap := make(map[string]bool)
	for _, word := range wordDict {
		wordMap[word] = true
	}

	// 2. init dp
	dp := make([]bool, len(s)+1)
	dp[0] = true // for everytime valid segment check must start from index 0

	for i := 1; i <= len(s); i++ {

		for j := 0; j <= i; j++ {
			if !dp[j] {
				continue // only last valid segment position
			}

			word := s[j:i]
			if wordMap[word] {
				dp[i] = true
				break
			}
		}
	}

	return dp[len(s)]
}

// @lc code=end

