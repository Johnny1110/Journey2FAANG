# 125. Valid Palindrome

<br>

---

<br>

## Desc

A phrase is a palindrome if, after converting all uppercase letters into lowercase letters and removing all non-alphanumeric characters, it reads the same forward and backward. Alphanumeric characters include letters and numbers.

Given a string `s`, return `true` if it is a palindrome, or `false` otherwise.

## Coding

```go
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
```

<br>

* 490/490 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 99.13 % of golang submissions (4.5 MB)

<br>
<br>

## Time & Space Compelxity

```
Assume: N = len(s)

Time: O(N)
Space: O(1)
```
