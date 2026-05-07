# 66. Plus One

<br>

---

<br>

## Coding

```go
func plusOne(digits []int) []int {
	idx := len(digits) - 1

	for {

		if idx == -1 {
			// add 1 at first
			digits = append([]int{1}, digits...)
			break
		}

		digits[idx] += 1
		if digits[idx] == 10 {
			digits[idx] = 0
			idx--
		} else {
			break
		}
	}

	return digits
}
```

<br>

### Clear Version

```go
func plusOne(digits []int) []int {
	for i := len(digits) - 1; i >= 0; i-- {
		if digits[i] < 9 {
			digits[i]++
			return digits
		}

		digits[i] = 0
	}

	// need i more space to put 1
	return append([]int{1}, digits...)
}
```

<br>
<br>

## Time & Space Complexity

```
Assume: n = len of digits

Time: O(n) -> worst case is  ~ O(2n) need add 1 at index-0

Space: O(1) -> no extra space needed but worst case is  ~ O(n) need 1 new slice for all 9 elements e.g. [9, 9, 9] 
```