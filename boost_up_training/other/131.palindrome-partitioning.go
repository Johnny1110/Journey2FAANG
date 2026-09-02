/*
 * @lc app=leetcode id=131 lang=golang
 *
 * [131] Palindrome Partitioning
 */

// @lc code=start
func partition(s string) [][]string {
	result := [][]string{}
	currentState := []string{}

	var backtracking func(start int)
	backtracking = func(start int) {
		// base case goes here
		if start == len(s) {
			tmp := make([]string, len(currentState))
			copy(tmp, currentState)
			result = append(result, tmp)
			return
		}

		// loop comes later — leave it out for now
		for end := start; end < len(s); end++ {
			piece := s[start : end+1]
			if isPalindrome(piece) {
				currentState = append(currentState, piece)        // update state
				backtracking(end + 1)                             // dfs
				currentState = currentState[:len(currentState)-1] // fallback state
			}
		}
	}

	backtracking(0) // start from first
	return result
}

func isPalindrome(s string) bool {
	a, b := 0, len(s)-1

	for a < b {
		if s[a] != s[b] {
			return false
		}
		a++
		b--
	}

	return true
}

// @lc code=end

