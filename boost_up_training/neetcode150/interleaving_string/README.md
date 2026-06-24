# 97. Interleaving String

<br>

---

<br>

## Desc

Given strings s1, s2, and s3, find whether s3 is formed by an interleaving of s1 and s2.

An interleaving of two strings s and t is a configuration where s and t are divided into n and m substrings respectively, such that:

```
s = s1 + s2 + ... + sn
t = t1 + t2 + ... + tm
|n - m| <= 1
The interleaving is s1 + t1 + s2 + t2 + s3 + t3 + ... or t1 + s1 + t2 + s2 + t3 + s3 + ...
```

<br>

### Example - 1:

```
Input: s1 = "aabcc", s2 = "dbbca", s3 = "aadbbcbcac"
Output: true
```

Explanation: One way to obtain s3 is:

* Split s1 into s1 = "aa" + "bc" + "c", and s2 into s2 = "dbbc" + "a".
* Interleaving the two splits, we get "aa" + "dbbc" + "bc" + "a" + "c" = "aadbbcbcac".
* Since s3 can be obtained by interleaving s1 and s2, we return true.


### Example - 2:

```
Input: s1 = "aabcc", s2 = "dbbca", s3 = "aadbbbaccc"
Output: false
```

Explanation: Notice how it is impossible to interleave s2 with any other string to obtain s3.

<br>
<br>

### Hints

When you see:

* merge two sequences
* preserve relative order
* choose from A or B

you should immediately think:

```
dp[i][j]
= using first i chars of A
  and first j chars of B
```

<br>
<br>

## Coding

```go
func isInterleave(s1 string, s2 string, s3 string) bool {
	if len(s3) != len(s1)+len(s2) {
		return false
	}

	// dynamic-programming
	// define dp dp[i][j] -> from s1[0~i] + from s2(0~j) = s3(0~i+j)
	dp := make([][]bool, len(s1)+1)
	for i := 0; i <= len(s1); i++ {
		dp[i] = make([]bool, len(s2)+1)
	}

	// init dp
	dp[0][0] = true
	for i := 0; i < len(s1); i++ {
		charA, charB := s1[i], s3[i]
		if charA == charB && dp[i][0] {
			dp[i+1][0] = true
		} else {
			break
		}
	}

	for j := 0; j < len(s2); j++ {
		charA, charB := s2[j], s3[j]
		if charA == charB && dp[0][j] {
			dp[0][j+1] = true
		} else {
			break
		}
	}

	for i := 1; i <= len(s1); i++ { // skip 0 (already init)
		for j := 1; j <= len(s2); j++ { // skip 0 (already init)
			s3Char := s3[i+j-1]
			s1Char := s1[i-1]
			s2Char := s2[j-1]

			// 1. from dp[i-1][j] -> dp[i][j]  (use s1)
			if dp[i-1][j] && s1Char == s3Char {
				dp[i][j] = true
				continue
			}
			// 2. from dp[i][j-1] -> dp[i][j] (use s2)

			if dp[i][j-1] && s2Char == s3Char {
				dp[i][j] = true
				continue
			}
		}
	}

	return dp[len(s1)][len(s2)]
}
```


* 107/107 cases passed (2 ms)
* Your runtime beats 69.59 % of golang submissions
* Your memory usage beats 86.08 % of golang submissions (4 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: n = len(s3)
Time: O(n)
Space: O(n)
```

<br>


## Minor improvements

### Unnecessary `continue`

```go
if dp[i-1][j] && s1Char == s3Char {
    dp[i][j] = true
    continue
}
```

using this to replace:

```go
dp[i][j] =
    (dp[i-1][j] && s1[i-1] == s3[i+j-1]) ||
    (dp[i][j-1] && s2[j-1] == s3[i+j-1])
```

<br>

### Revised version

```go
func isInterleave(s1 string, s2 string, s3 string) bool {
	if len(s3) != len(s1)+len(s2) {
		return false
	}

	// dynamic-programming
	// define dp dp[i][j] -> from s1[0~i] + from s2(0~j) = s3(0~i+j)
	dp := make([][]bool, len(s1)+1)
	for i := 0; i <= len(s1); i++ {
		dp[i] = make([]bool, len(s2)+1)
	}

	// init dp
	dp[0][0] = true
	for i := 0; i < len(s1); i++ {
		charA, charB := s1[i], s3[i]
		if charA == charB && dp[i][0] {
			dp[i+1][0] = true
		} else {
			break
		}
	}

	for j := 0; j < len(s2); j++ {
		charA, charB := s2[j], s3[j]
		if charA == charB && dp[0][j] {
			dp[0][j+1] = true
		} else {
			break
		}
	}

	for i := 1; i <= len(s1); i++ { // skip 0 (already init)
		for j := 1; j <= len(s2); j++ { // skip 0 (already init)
			s3Char := s3[i+j-1]
			s1Char := s1[i-1]
			s2Char := s2[j-1]

			dp[i][j] = (dp[i-1][j] && s1Char == s3Char) || (dp[i][j-1] && s2Char == s3Char)
		}
	}

	return dp[len(s1)][len(s2)]
}
```

* 107/107 cases passed (2 ms)
* Your runtime beats 69.59 % of golang submissions
* Your memory usage beats 50.52 % of golang submissions (4.3 MB)

## Time & Space Complexity

```
define:
m = len(s1)
n = len(s2)

Time: O(mn)
Space: O(mn)
```