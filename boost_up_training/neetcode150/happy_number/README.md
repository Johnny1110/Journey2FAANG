# 202. Happy Number

<br>


---

<br>

## Coding

```go
func isHappy(n int) bool {
	hashset := make(map[int]bool)

	sum := 0

	for n != 1 {

		if hashset[n] {
			return false
		}
		hashset[n] = true // mark n visited

		for n > 0 {
			a := n % 10
			n = n / 10
			sum += a * a
		}

		n = sum
		sum = 0
	}

	return true
}
```

* 423/423 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 13.9 % of golang submissions (4.7 MB)

<br>
<br>

## Time & Space Complexity

```
Time:  O(log n)   — digit sum is O(log n); after the first steps values stay ≤ 243
Space: O(log n)   — hashset of seen values (bounded by ~243 entries in practice)
```

<br>

## Coding - O(1)

```go
func isHappy(n int) bool {
	// cycle detect algo
	next := func(x int) int {
		sum := 0
		for x > 0 {
			a := x % 10
			x = x / 10
			sum += a * a
		}
		return sum
	}

	slow, fast := n, next(n)

	for fast != 1 && slow != fast {
		slow, fast = next(slow), next(next(fast))
	}

	return fast == 1
}
```