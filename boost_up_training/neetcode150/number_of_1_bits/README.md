# 191. Number of 1 Bits

<br>

---

<br>

## Desc

Given a positive integer `n`, write a function that returns the number of set bits in its binary representation (also known as the Hamming weight).

Example 1:

```
Input: n = 11

Output: 3


Explanation:

The input binary string 1011 has a total of three set bits.
```

Example 2:

```
Input: n = 128

Output: 1

Explanation:

The input binary string 10000000 has a total of one set bit.
```

<br>
<br>

## Coding

```go
func hammingWeight(n int) int {
	cnt := 0
	mapping := 1

	for n > 0 {
		if n&mapping == 1 {
			cnt++
		}
		n = n >> 1
	}

	return cnt
}
```

* 598/598 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 5.51 % of golang submissions (4.6 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = length of n in bit represent
Time: O(N)
Space: O(1)
```