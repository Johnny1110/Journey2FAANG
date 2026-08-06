/*
 * @lc app=leetcode id=124 lang=golang
 *
 * [124] Binary Tree Maximum Path Sum
 */

// @lc code=start
/**
 * Definition for a binary tree node.
 * type TreeNode struct {
 *     Val int
 *     Left *TreeNode
 *     Right *TreeNode
 * }
 */
func maxPathSum(root *TreeNode) int {
	best := math.MinInt

	// gain return best path
	var gain func(node *TreeNode) int

	gain = func(node *TreeNode) int {
		if node == nil {
			return 0
		}

		l, r := gain(node.Left), gain(node.Right)

		best = max(best, l+r+node.Val)
		return max(node.Val+max(l, r), 0)
	}

	gain(root)
	return best
}

// @lc code=end

