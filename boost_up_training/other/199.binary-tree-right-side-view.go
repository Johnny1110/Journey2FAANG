/*
 * @lc app=leetcode id=199 lang=golang
 *
 * [199] Binary Tree Right Side View
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
func rightSideView(root *TreeNode) []int {
	result := []int{}

	if root == nil {
		return result
	}

	var dfs func(node *TreeNode, depth int)
	dfs = func(node *TreeNode, depth int) {
		if node == nil {
			return
		}

		if depth == len(result) {
			result = append(result, node.Val)
		}

		// visit right first
		dfs(node.Right, depth+1)
		dfs(node.Left, depth+1)
	}

	dfs(root, 0)

	return result
}

// @lc code=end

