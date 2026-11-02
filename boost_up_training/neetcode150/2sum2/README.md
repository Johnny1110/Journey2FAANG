# 167. Two Sum II - Input Array Is Sorted

<br>

## Coding

```go
func twoSum(numbers []int, target int) []int {
	// [-1, 0], target = -1
	for a := 0; a < len(numbers)-1; a++ {
		wanted := target - numbers[a]

		//fmt.Printf("wanted=%v \n", wanted)

		// using bin-search to find wanted number
		left, right := a+1, len(numbers)-1
		for left <= right {
			mid := (left + right) / 2

			//fmt.Printf("mid=%v val :=%v \n", mid, numbers[mid])

			if numbers[mid] > wanted {
				// go left
				right = mid - 1
			} else if numbers[mid] < wanted {
				// go right
				left = mid + 1
			} else {
				// found
				return []int{a + 1, mid + 1}
			}
		}

	}

	return []int{}
}
```

* 26/26 cases passed (2 ms)
* Your runtime beats 13.91 % of golang submissions
* Your memory usage beats 18.86 % of golang submissions (8.5 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = length of numbers

Time: O(N * log N)
Space: O(1)
```

<br>
<br>

## Optimized - Two Pointers (O(N))

```go
func twoSum(numbers []int, target int) []int {
	left, right := 0, len(numbers)-1
	for left < right {
		sum := numbers[left] + numbers[right]

		if sum == target {
			return []int{left + 1, right + 1}
		} else if sum > target {
			// need a smaller sum
			right--
		} else {
			// need a bigger sum
			left++
		}
	}

	return []int{}
}
```

* 26/26 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 82.74 % of golang submissions (8.1 MB)