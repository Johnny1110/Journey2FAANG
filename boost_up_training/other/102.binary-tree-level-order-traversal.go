/*
 * @lc app=leetcode id=102 lang=golang
 *
 * [102] Binary Tree Level Order Traversal
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
func levelOrder(root *TreeNode) [][]int {
	result := [][]int{}

	if root == nil {
		return result
	}

	queue := Queue([]*TreeNode{})
	queue.Push(root)

	for queue.Len() != 0 {
		levelLen := queue.Len()
		level := make([]int, levelLen)
		for i := range levelLen {
			node := queue.Pop()
			level[i] = node.Val

			if node.Left != nil {
				queue.Push(node.Left)
			}
			if node.Right != nil {
				queue.Push(node.Right)
			}
		}
		result = append(result, level)
	}

	return result
}

type Queue []*TreeNode

func (q Queue) Len() int {
	return len(q)
}

func (q *Queue) Push(node *TreeNode) {
	*q = append(*q, node)
}

func (q *Queue) Pop() *TreeNode {
	node := (*q)[0]
	*q = (*q)[1:]
	return node
}

// @lc code=end

