# 678. Valid Parenthesis String

<br>

---

<br>

## Coding

```go
func checkValidString(s string) bool {
	// tracking open count range
	min, max := 0, 0

	for _, char := range s {
		if char == '(' {
			// open
			min++
			max++
		} else if char == ')' {
			// close
			if min > 0 {
				min--
			}
			max--

			if max < 0 {
				return false // can not accept )
			}

		} else {
			// wildcard
			if min > 0 {
				min--
			}
			max++
		}
	}

	return min == 0
}
```

* 85/85 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 100 % of golang submissions (3.7 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: Assume N = s length

Time: O(N)
Space: O(1)
```