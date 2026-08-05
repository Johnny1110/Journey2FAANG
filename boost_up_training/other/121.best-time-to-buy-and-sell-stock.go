/*
 * @lc app=leetcode id=121 lang=golang
 *
 * [121] Best Time to Buy and Sell Stock
 */

// @lc code=start
func maxProfit(prices []int) int {
	bestProfit, minPrice := 0, math.MaxInt32

	for _, p := range prices {
		minPrice = min(p, minPrice)
		bestProfit = max(p-minPrice, bestProfit)
	}
	return bestProfit
}

// @lc code=end

