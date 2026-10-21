# 153. Find Minimum in Rotated Sorted Array

<br>

---

<br>

## Coding

```go
func findMin(nums []int) int {
	// find out reverse point?

	left, right, mid := 0, len(nums)-1, 0

	for left < right {
		// mid = left + (right-left)/2
		mid = (left + right) / 2
		midVal, rightVal := nums[mid], nums[right]

		if midVal > rightVal {
			// target "min" is on right side (after curr mid)
			left = mid + 1
		} else {
			right = mid
		}
	}

	return nums[left]
}
```

* nums[mid] > nums[right]：比右段的數還大，所以 mid 一定在左段。最小值在 mid 右邊，而 mid 本身不可能是答案，因此 left = mid + 1。
* nums[mid] < nums[right]：mid 在右段。最小值在 mid 或更左邊，而 mid 本身有可能就是答案，所以不能丟掉它，因此 right = mid。

<br>
<br>

## Time & Space Complexity

```
Assume: N = len of nums

Time: O(log N)
Space: O(1)
```