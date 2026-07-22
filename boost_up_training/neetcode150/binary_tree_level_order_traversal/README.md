# 102. Binary Tree Level Order Traversal

<br>

---

<br>

## Coding

```go
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
```

* 35/35 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 45.86 % of golang submissions (5.5 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = size of nodes

Time: O(N)
Space: O(N)
```