/*
 * @lc app=leetcode id=110 lang=golang
 *
 * [110] Balanced Binary Tree
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
func isBalanced(root *TreeNode) bool {
	if root == nil {
		return true
	}

	leftHeight, b1 := height(root.Left)
	rightHeight, b2 := height(root.Right)

	if !b1 || !b2 {
		return false
	}

	//fmt.Printf("leftHeight: %v \n", leftHeight)
	//fmt.Printf("rightHeight: %v \n", rightHeight)

	absDiff := abs(leftHeight - rightHeight)
	return absDiff <= 1
}

func height(node *TreeNode) (int, bool) {
	if node == nil {
		return 0, true
	}

	leftHeight, b1 := height(node.Left)
	rightHeight, b2 := height(node.Right)
	if !b1 || !b2 {
		return 0, false // found not balance in sub nodes
	}

	absDiff := abs(leftHeight - rightHeight)
	val := max(leftHeight, rightHeight)

	return val + 1, absDiff <= 1
}

func abs(val int) int {
	if val > 0 {
		return val
	}
	return -val
}

// @lc code=end

