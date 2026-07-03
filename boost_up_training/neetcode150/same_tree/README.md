# 100. Same Tree

<br>

---

<br>

## Coding - 1

```go
func isSameTree(p *TreeNode, q *TreeNode) bool {
	if p == nil && q == nil {
		return true
	} else if p == nil || q == nil {
		return false
	}

	if p.Val != q.Val {
		return false
	}

	return isSameTree(p.Left, q.Left) && isSameTree(p.Right, q.Right)
}
```

67/67 cases passed (0 ms)
Your runtime beats 100 % of golang submissions
Your memory usage beats 5.65 % of golang submissions (4.2 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: n = length of minTree size, h = max(height(p), height(q))

Time: O(n)
Space: O(h)
```