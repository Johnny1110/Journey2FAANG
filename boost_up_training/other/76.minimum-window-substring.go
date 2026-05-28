/*
 * @lc app=leetcode id=76 lang=golang
 *
 * [76] Minimum Window Substring
 */

// @lc code=start
func minWindow(s string, t string) string {
	if len(t) > len(s) {
		return ""
	}
	// standard slide window
	need := len(t)
	needT := make(map[byte]int)

	for i := range t {
		needT[t[i]]++
	}

	bestStart, bestLen := 0, len(s)+1 // best len longer than s, we can check answer exists or not by it.

	left := 0
	for right := 0; right < len(s); right++ {
		// keep right pointer forward >>>> >>>> >>>> >>>>
		letter := s[right]
		if cnt, exists := needT[letter]; exists {
			needT[letter]--
			if cnt > 0 { // only cnt = 0 is real reduce time
				need--
			}
		}

		// start shrink >>>> >>>> >>>> >>>>
		for need == 0 && left < len(s) {
			if right-left+1 < bestLen { // mark best record
				bestStart = left
				bestLen = right - left + 1
			}

			letter := s[left]
			left++ // move left pointer forward
			if cnt, exists := needT[letter]; exists {
				needT[letter]++
				if cnt == 0 { // 又產生缺口
					need++ // 打開缺口
				}
			}
		}
	}

	if bestLen == len(s)+1 {
		return ""
	}

	return s[bestStart : bestStart+bestLen]
}

// @lc code=end

