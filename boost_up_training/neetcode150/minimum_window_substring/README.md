# 76. Minimum Window Substring

<br>

---

<br>

## Hint

* hash-table
* two-pointers
* string
* sliding-window

<br>

## Coding

```go
func minWindow(s string, t string) string {
	if len(t) > len(s) {
		return ""
	}

	need := len(t)
	needT := make(map[byte]int)
	for _, letter := range t {
		needT[byte(letter)]++
	}

	shrinkFlag := false
	best := []int{0, 0}
	left, right := 0, 0

	for right < len(s) || shrinkFlag {

		for shrinkFlag { // shrink loop

			letter := s[left]
			letterCnt, exists := needT[letter]

			if !exists { // garbage letter
				left++
			} else if letterCnt == 0 {
				shrinkFlag = false
			} else {
				left++
				needT[letter]++
			}

			length := right - left
			if best[1] == 0 || best[1]-best[0] > length {
				best[0], best[1] = left, right
			}
		}

		// expend right
		if right < len(s) {

			letter := s[right]
			letterCnt, exists := needT[letter]
			if exists {
				needT[letter]--
				if letterCnt > 0 {
					need--
				}

				if need == 0 {
					shrinkFlag = true
				}
			}

			right++
		}

	}

	if need == 0 {
		return s[best[0]:best[1]]
	} else {
		return ""
	}
}
```

<br>

## Time & Space Complexity

```
Assume: m = len(s), n = len(t)

Time: O(m)

Space:  0(n) -> need a map to store letter count in t.
```


<br>

## Standard Slide Window

```go
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
```

* 268/268 cases passed (18 ms)
* Your runtime beats 65.22 % of golang submissions
* Your memory usage beats 65.35 % of golang submissions (5.2 MB)