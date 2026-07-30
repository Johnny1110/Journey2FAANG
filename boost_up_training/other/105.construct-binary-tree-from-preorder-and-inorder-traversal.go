/*
 * @lc app=leetcode id=105 lang=golang
 *
 * [105] Construct Binary Tree from Preorder and Inorder Traversal
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
// pre: [3, 9, 20, 15, 7]
// in : [9, 3, 15, 20, 7]
func buildTree(preorder []int, inorder []int) *TreeNode {
	if len(preorder) == 0 {
		return nil
	}

	inMap := make(map[int]int)
	for i, val := range inorder {
		inMap[val] = i
	}

	var build func(preLeft, preRight, inLeft, inRight int) *TreeNode
	build = func(preLeft, preRight, inLeft, inRight int) *TreeNode {

		if preLeft > preRight {
			return nil
		}

		root := newNode(preorder[preLeft])
		rootIdxOnInorder := inMap[root.Val]    // 1
		leftCount := rootIdxOnInorder - inLeft // 1 - 0 = 1
		//rightCount := inRight - rootIdxOnInorder // 4 - 1 = 3

		// left
		root.Left = build(preLeft+1, preLeft+leftCount, inLeft, rootIdxOnInorder-1)
		//right
		root.Right = build(preLeft+leftCount+1, preRight, rootIdxOnInorder+1, inRight)

		return root
	}

	return build(0, len(preorder)-1, 0, len(inorder)-1)
}

func newNode(val int) *TreeNode {
	return &TreeNode{
		Val: val,
	}
}

// @lc code=end

