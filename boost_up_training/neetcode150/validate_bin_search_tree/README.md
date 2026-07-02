# 98. Validate Binary Search Tree

<br>

---

<br>

## A valid BST is defined as follows:

* The left subtree of a node contains only nodes with keys strictly less than the node's key.
* The right subtree of a node contains only nodes with keys strictly greater than the node's key.
* Both the left and right subtrees must also be binary search trees.

<br>

## Coding

```go
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
```


* 86/86 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 75.88 % of golang submissions (7.2 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: n = size of NodeTree, Tree Height = h

Time: O(n)
Space: O(h)
```