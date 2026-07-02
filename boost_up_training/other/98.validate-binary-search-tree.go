/*
 * @lc app=leetcode id=98 lang=golang
 *
 * [98] Validate Binary Search Tree
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
func isValidBST(root *TreeNode) bool {
	if root == nil {
		return true
	}

	return verify(root, math.MaxInt, math.MinInt)
}

func verify(node *TreeNode, max, min int) bool {
	if node == nil {
		return true
	}

	val := node.Val
	if val >= max || val <= min {
		return false
	}

	return verify(node.Left, val, min) && verify(node.Right, max, val)
}

// @lc code=end

