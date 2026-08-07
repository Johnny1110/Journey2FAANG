/*
 * @lc app=leetcode id=125 lang=golang
 *
 * [125] Valid Palindrome
 */

// @lc code=start
func isPalindrome(s string) bool {
	// A: 65 Z: 90 a: 97 z: 122
	if len(s) == 1 {
		return true
	}

	pointerA, pointerB := 0, len(s)-1
	for pointerA <= pointerB {
		a, b := lowercase(s[pointerA]), lowercase(s[pointerB])

		for a == -1 && pointerA < pointerB {
			pointerA++
			a = lowercase(s[pointerA])
		}

		for b == -1 && pointerA < pointerB {
			pointerB--
			b = lowercase(s[pointerB])
		}

		if a != b {
			return false
		}

		pointerA++
		pointerB--
	}

	return true
}

func lowercase(c byte) int {
	// A~Z: 65 ~ 90
	// a~z: 97 ~ 122
	if c >= 'A' && c <= 'Z' {
		return int(c) + 32
	}
	if c >= 'a' && c <= 'z' {
		return int(c)
	}
	if c >= '0' && c <= '9' {
		return int(c)
	}

	return -1
}

// @lc code=end

