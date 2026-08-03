# 110. Balanced Binary Tree

<br>

---

<br>

## Desc

Given a binary tree, determine if it is height-balanced.

height-balanced binary tree:

> For every node, the height difference between its left and right subtrees is at most 1.


## Coding


```go
func isBalanced(root *TreeNode) bool {
	if root == nil {
		return true
	}

	leftHeight, b1 := height(root.Left)
	rightHeight, b2 := height(root.Right)

	if !b1 || !b2 {
		return false
	}

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
```

<br>

* 228/228 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 88.22 % of golang submissions (7.3 MB)

<br>

## Time & Space Complexity

```
Assume: N = number of nodes, H = tree height

Time: O(N)
Space: O(H) -> call stack
```