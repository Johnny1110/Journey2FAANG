# 199. Binarty Tree Right Side View

<br>

---

<br>

## Coding - BFS

```go
func rightSideView(root *TreeNode) []int {
	result := []int{}

	if root == nil {
		return result
	}

	// init quque
	q := Queue([]*TreeNode{})
	q.Push(root)

	for q.Len() > 0 {
		levelLen := q.Len()
		for i := 0; i < levelLen; i++ {
			n := q.Pop()
			// put left&right into next queue's level
			if n.Left != nil {
				q.Push(n.Left)
			}
			if n.Right != nil {
				q.Push(n.Right)
			}

			if i == levelLen-1 {
				// curr level last one
				result = append(result, n.Val)
			}
		}
	}

	return result
}

type Queue []*TreeNode

func (q *Queue) Len() int {
	return len(*q)
}

func (q *Queue) Push(n *TreeNode) {
	*q = append(*q, n)
}

func (q *Queue) Pop() *TreeNode {
	p := *q
	v := p[0]
	p[0] = nil
	*q = p[1:]
	return v
}
```

* 217/217 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 10.02 % of golang submissions (5 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = size of nodes

Time = O(N)
Space = O(N)
```

<br>
<br>

## Coding - DFS


```go
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
```
