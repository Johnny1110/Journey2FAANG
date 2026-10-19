# 152. Maximum Product Subarray 

<br>

---

<br>

## Example

​​​​​​​Example 1:

```
Input: nums = [2,3,-2,4]
Output: 6
Explanation: [2,3] has the largest product 6.
```

Example 2:

```
Input: nums = [-2,0,-1]
Output: 0
Explanation: The result cannot be 2, because [-2,-1] is not a subarray.
```

<br>
<br>

## Coding

```go
func maxProduct(nums []int) int {
	n := len(nums)
	// define dp[i] -> max product include nums[i]
	dpMax := make([]int, n)
	dpMin := make([]int, n)
	dpMax[0], dpMin[0] = nums[0], nums[0]

	answer := nums[0]
	for i := 1; i < n; i++ {
		currNum := nums[i]
		dpMax[i] = max(dpMax[i-1]*currNum, dpMin[i-1]*currNum, currNum)
		dpMin[i] = min(dpMax[i-1]*currNum, dpMin[i-1]*currNum, currNum)

		answer = max(answer, dpMax[i])
	}

	return answer
}
```

* 192/192 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 9.09 % of golang submissions (6 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = length of nums

Time: O(N)
Space: O(2*N)
```