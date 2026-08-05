# 121. Best Time to Buy and Sell Stock

<br>

---

<br>

## Example

```
Input: prices = [7,1,5,3,6,4]
Output: 5
Explanation: Buy on day 2 (price = 1) and sell on day 5 (price = 6), profit = 6-1 = 5.
Note that buying on day 2 and selling on day 1 is not allowed because you must buy before you sell.
```

## Coding

```go
func maxProfit(prices []int) int {
	n := len(prices)
	suffix := make([]int, n)

	cur := 0
	for i := n - 1; i >= 0; i-- {
		cur = max(prices[i], cur)
		suffix[i] = cur
	}

	profit := 0
	for i := 0; i < n; i++ {
		a := prices[i]
		b := suffix[i]
		profit = max(b-a, profit)
	}

	return profit
}
```

* 212/212 cases passed (12 ms)
* Your runtime beats 5.59 % of golang submissions
* Your memory usage beats 20.06 % of golang submissions (11.3 MB)

<br>
<br>

## Time & Space Compelxity

```
Assume: N = len(prices)

Time: O(2N)
Space: O(N)
```

<br>
<br>

## Optimized Approach

```go
func maxProfit(prices []int) int {
	bestProfit, minPrice := 0, math.MaxInt32

	for _, p := range prices {
		minPrice = min(p, minPrice)
		bestProfit = max(p-minPrice, bestProfit)
	}
	return bestProfit
}
```