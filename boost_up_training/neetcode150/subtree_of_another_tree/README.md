# 572. Subtree of Another Tree

<br>

---

<br>

## Coding

```go
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
```

<br>
<br>

## Time & Space Complexity

```
Assume: n = layer of nodeA, m = layer of nodeB

Time: O(log n * log m)

Space: O(log n * log m)
```

<br>
<br>

## AI Feedback

You wrote: Time: `O(log n * log m)` where `n` and `m` are the layers (heights) of the trees.
There are two issues here.

### Issue 1: n and m should be node counts, not heights

This is convention, but it matters because it changes what the bound means. In tree problems, n almost universally means "number of nodes in the tree." Let me redefine:

* `n` = number of nodes in root
* `m` = number of nodes in subRoot

### Issue 2: Where does log even come from?

This is the deeper conceptual issue. log n shows up in tree algorithms when you traverse one root-to-leaf path in a balanced tree — because the height of a balanced tree is O(log n).

But your algorithm doesn't traverse just one path. Look at dfs:

```go
return dfs(nodeA.Left) || dfs(nodeA.Right)
```

When `tryMatch()` returns false, you recurse into both children. That means `dfs` visits every node in root, not just one path down. So the outer traversal is `O(n)`, not `O(log n)`.

Same story for `tryMatch` — in the worst case (the trees match all the way until the very end), it visits every node of subRoot, so it's `O(m)`, not `O(log m)`.

<br>
<br>

### The correct time complexity:

At each of the n nodes in root, you potentially call tryMatch, which is O(m) in the worst case. So:

```
Time: O(n × m)
```

This is the textbook answer for this problem.

<br>

### Space complexity

Space comes from the recursion call stack, not from how many nodes you visit. The stack depth at any moment is bounded by how deep you've recursed.

dfs recurses down root, so stack depth is O(h_root) where h_root is the height of root
While inside dfs, when you call tryMatch, you add another stack frame chain of depth O(h_subRoot)

So total space is `O(h_root + h_subRoot)`.
In the worst case (skewed trees, basically a linked list), heights equal node counts: `O(n + m)`.
In the balanced case: `O(log n + log m)`.