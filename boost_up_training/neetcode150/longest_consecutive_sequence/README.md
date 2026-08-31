# 128. Longest Consecutive Sequence

<br>

---

<br>

## Desc

Given an unsorted array of integers nums, return the length of the longest consecutive elements sequence.

You must write an algorithm that runs in O(n) time.

```
Input: nums = [100,4,200,1,3,2]
Output: 4

Explanation: The longest consecutive elements sequence is [1, 2, 3, 4]. Therefore its length is 4.
```

<br>

## Topic

* array 
* union-find

<br>

## Coding - Hastset solution

```go
func longestConsecutive(nums []int) int {
	if len(nums) == 0 {
		return 0
	}

	hs := make(map[int]int8)
	for _, n := range nums {
		hs[n] = 1
	}

	best := 0
	// 6
	for n := range hs {

		if hs[n-1] != 1 { // only from start
			temp := 1
			n++              // try to find next
			for hs[n] == 1 { // found next
				n++
				temp++
			}

			best = max(best, temp)
		}
	}

	return best
}
```

<br>
<br>

## Time & Space Complexity 

```
Assume: N = len(nums)

Time: O(N) ->  input or get hashset is O(N)
Space: O(N)
```