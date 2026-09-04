/*
 * @lc app=leetcode id=647 lang=golang
 *
 * [647] Palindromic Substrings
 */

// @lc code=start
func countSubstrings(s string) int {
	res := 0

	expand := func(l, r int) {
		for l >= 0 && r < len(s) && s[l] == s[r] {
			res++
			l--
			r++
		}
	}

	for i := range s {
		expand(i, i)
		expand(i, i+1)
	}

	return res
}

// @lc code=end

