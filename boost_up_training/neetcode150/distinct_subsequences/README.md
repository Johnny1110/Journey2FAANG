# 115. Distinct Subsequences

<br>

---

<br>

## Desc

Hints: 

* string 
* dynamic-programming

Example: 

```
Input: s = "rabbbit", t = "rabbit"
Output: 3

Explanation:
There are 3 ways you can generate "rabbit" from s.
```

<br>

## Define DP

dp[i][j] = number of distinct ways to form t[0..j-1] using s[0..i-1] as a subsequence

## Transform State

```
dp[i][j] = dp[i-1][j] + (s[i-1] == t[j-1] ? dp[i-1][j-1] : 0)
```

<br>

## Coding

```go
func numDistinct(s string, t string) int {
	// define dp:
	// i: from 0 chars to i chars of string s
	// j: from 0 chars to j chars of string t
	// value: the possible way to transfer from s[0:i-1] to t[0:j-1]
	dp := make([][]int, len(s)+1)
	for i := 0; i <= len(s); i++ {
		dp[i] = make([]int, len(t)+1)
		// dp[i][0] = 1 -> all string s become to empty have 1 way, adapt nothing.
		dp[i][0] = 1
	}
	// empty -> empty = 1
	dp[0][0] = 1

	// fill-in the DP
	for i := 1; i <= len(s); i++ {
		for j := 1; j <= len(t); j++ {
			// i chars from s
			// j chars from t

			dp[i][j] = dp[i-1][j] // skip s[i-1]

			if s[i-1] == t[j-1] {
				// both chars are the same
				dp[i][j] += dp[i-1][j-1]
			}
		}
	}

	return dp[len(s)][len(t)]
}
```

<br>

## Time & Space Compelxity

```
Assume: M = len(s), N = len(t)

Tim
e: O(M*N)
Space: O(M*N)
```
<br>

## Conclusion

### 下次遇到雙序列 DP，照這個跑：

* 誰有決策權？ 哪一側的字元可以被丟棄／跳過？→ 決定枚舉哪一側。
* 一個「方案」的實體是什麼？ 具體寫出來（本題是遞增下標組合）。
* 對最後一個字元問一個二元問題，切出不重不漏的分類。
* 每一類獨立化簡：這一類的方案，剝掉已決定的部分後，剩下什麼子問題？前提條件是什麼？
* 合併：計數題用 +，最佳化題用 max/min。