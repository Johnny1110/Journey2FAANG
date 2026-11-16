# 198. House Robber

<br>

---

<br>

## Desc

You are a professional robber planning to rob houses along a street. Each house has a certain amount of money stashed, the only constraint stopping you from robbing each of them is that adjacent houses have security systems connected and it will automatically contact the police if two adjacent houses were broken into on the same night.

Given an integer array nums representing the amount of money of each house, return the maximum amount of money you can rob tonight without alerting the police.

 

Example 1:
```
Input: nums = [1,2,3,1]
Output: 4
Explanation: Rob house 1 (money = 1) and then rob house 3 (money = 3).
Total amount you can rob = 1 + 3 = 4.
```

<br>
<br>

## Coding

```go
func rob(nums []int) int {
	if len(nums) == 1 {
		return nums[0]
	}
	// define dp[i]: max profit when stand on i house
	dp := make([]int, len(nums))
	dp[0], dp[1] = nums[0], max(nums[0], nums[1])

	// start iterate
	for i := 2; i < len(nums); i++ {
		currVal := nums[i]

		robVal := currVal + dp[i-2]
		norobVal := dp[i-1]

		dp[i] = max(robVal, norobVal)
	}

	return dp[len(nums)-1]
}
```

* 70/70 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 5.08 % of golang submissions (4.8 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = len(nums)

Time: O(N)
Space: O(N)
```

<br>
<br>

## Coding - O(1) Space

```go
func rob(nums []int) int {
	if len(nums) == 1 {
		return nums[0]
	}

	prev1, prev2 := 0, 0

	for _, n := range nums {
		prev2, prev1 = prev1, max(prev1, prev2+n)
	}

	return prev1
}
```