# 124. Binary Tree Maximum Path Sum

<br>

---

<br>

## Thinking

What I want to know from sub nodes:

* Best result you found (could be a final answer)
* Best path you found (only left or right 1 way)

<br>
<br>

## Coding

```go
func maxPathSum(root *TreeNode) int {
	res, _ := resolve(root)
	return res
}

func resolve(node *TreeNode) (int, int) {
	if node == nil {
		return math.MinInt32, 0
	}

	currVal := node.Val // this node val

	// What I want to know from sub nodes:
	// * Best result you found (could be a final answer)
	// * Best path you found (only left or right 1 way)

	leftBestResult, leftBestPath := resolve(node.Left)
	rightBestResult, rightBestPath := resolve(node.Right)

	// thisBestResult: count currVal in, connect leftPath and rightPath
	thisBestResult := leftBestPath + rightBestPath + currVal
	// calculate bestResult
	bestResult := max(thisBestResult, leftBestResult, rightBestResult)

	// calculate bestPath
	maxSubPath := max(leftBestPath, rightBestPath)
	bestPath := max(currVal+maxSubPath, 0)

	return bestResult, bestPath
}
```

* 96/96 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 84.47 % of golang submissions (9.9 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = node Count, H = NodeTree Height

Time: O(N) every node will iterate at least once.
Space: O(H) max call stack is tree height, also could be O(log N) -> log N = tree height
```

<br>

## Coding Style Enhancement

```go
func maxPathSum(root *TreeNode) int {
	best := math.MinInt

	// gain return best path
	var gain func(node *TreeNode) int

	gain = func(node *TreeNode) int {
		if node == nil {
			return 0
		}

		l, r := gain(node.Left), gain(node.Right)

		best = max(best, l+r+node.Val)
		return max(node.Val+max(l, r), 0)
	}

	gain(root)
	return best
}
```