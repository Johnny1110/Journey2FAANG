/*
 * @lc app=leetcode id=76 lang=golang
 *
 * [76] Minimum Window Substring
 */

// @lc code=start
func minWindow(s string, t string) string {
	totalCnt := len(t)
	letters := make([]int, 52)
	// fill the letters
	for _, l := range t {
		letters[letterIdx(uint8(l))]++

	}

	fmt.Printf("letters: %v \n", letters)

	return ""
}

// A: 65 Z: 90 a: 97 z: 122
func letterIdx(letter uint8) uint8 {
	if letter >= 65 && letter <= 90 {
		// A~Z
		return letter - 65
	} else {
		return letter - 65 - 6
	}
	return 0
}

// @lc code=end

