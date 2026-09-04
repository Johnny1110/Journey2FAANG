# 647. Palindromic Substrings

<br>

---

<br>

## EX

```
Input: s = "abc"
Output: 3
Explanation: Three palindromic strings: "a", "b", "c".
```

```
Input: s = "aaa"
Output: 6
Explanation: Six palindromic strings: "a", "a", "a", "aa", "aa", "aaa".
```

<br>
<br>

## Coding - Expanding from Center

```go
func countSubstrings(s string) int {
	res := 0

	for i := 0; i < len(s); i++ {

		pointerA, pointerB := i, i
		for pointerA >= 0 && pointerB < len(s) {
			if s[pointerA] == s[pointerB] {
				res++ // found a palidromic
			} else {
				break
			}
			pointerA--
			pointerB++
		}

		pointerA, pointerB = i, i+1
		for pointerA >= 0 && pointerB < len(s) {
			if s[pointerA] == s[pointerB] {
				res++ // found a palidromic
			} else {
				break
			}
			pointerA--
			pointerB++
		}
	}

	return res
}
```

### Refine Code Structure

```go
func countSubstrings(s string) int {
	res := 0

	expand := func(l, r int) {
		for l >= 0 && r < len(s) && s[l] == s[r] {
			res++
			l--
			r++
		}
	}

	for i := 0; i < len(s); i++ {
		expand(i, i)
		expand(i, i+1)
	}

	return res
}
```

<br>
<br>

## Time & Space Complexity

```
Assume: N = len(s)

Time: O(N^2)
Space: O(1)
```

<br>
<br>

## Coding - DP

```go

```


<br>
<br>

## Time & Space Complexity

```
Assume:

Time:
Space:
```