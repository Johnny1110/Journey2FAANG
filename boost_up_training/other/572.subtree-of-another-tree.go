/*
 * @lc app=leetcode id=572 lang=golang
 *
 * [572] Subtree of Another Tree
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
func isSubtree(root *TreeNode, subRoot *TreeNode) bool {

	var dfs func(nodeA *TreeNode) bool
	dfs = func(nodeA *TreeNode) bool {
		// 1. null check
		if nodeA == nil {
			return false
		}

		// go next layer with next left & next right
		return tryMatch(nodeA, subRoot) || dfs(nodeA.Left) || dfs(nodeA.Right)
	}

	return dfs(root)
}

func tryMatch(nodeA, nodeB *TreeNode) bool {
	// 1. null check (both end)
	if nodeA == nil && nodeB == nil {
		return true
	}
	// 2. run out of nodes
	if nodeA == nil || nodeB == nil {
		return false
	}

	if nodeA.Val == nodeB.Val {
		return tryMatch(nodeA.Left, nodeB.Left) && tryMatch(nodeA.Right, nodeB.Right)
	} else {
		return false
	}
}

// @lc code=end

