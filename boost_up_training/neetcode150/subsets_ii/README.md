# 90. Subsets II

<br>

---

<br>

## Coding

```go
func subsetsWithDup(nums []int) [][]int {
	sort.Ints(nums)

	result := [][]int{}
	state := make([]int, 0, len(nums))

	var backtracking func(idx int)
	backtracking = func(idx int) {
		tmp := make([]int, len(state))
		copy(tmp, state)
		result = append(result, tmp)

		for i := idx; i < len(nums); i++ {
			// dedup
			if i > idx && nums[i] == nums[i-1] {
				continue
			}
			state = append(state, nums[i])
			// go deeper
			backtracking(i + 1)
			// rollback
			state = state[:len(state)-1]
		}
	}

	backtracking(0)

	return result
}
```

<br>
<br>

## Time & Space Complexity

```
Assume:n = len of nums
Time: O(n * 2 n 次方) -> (每個數字選或不選, copy 是 O(n))
Space: O(n) backtracking recursive max callStack is n 
```