# 133. Clone Graph

<br>

---

<br>

## Coding

```go
func cloneGraph(node *Node) *Node {
	if node == nil {
		return nil
	}

	created := make(map[int]*Node)

	var dfs func(node *Node) *Node
	dfs = func(node *Node) *Node {
		if n, exists := created[node.Val]; exists {
			return n
		}

		n := makeNode(node.Val, len(node.Neighbors))
		created[n.Val] = n

		if node.Neighbors != nil {
			// create Neighbors clones
			for i, nber := range node.Neighbors {
				n.Neighbors[i] = dfs(nber)
			}
		}

		return n
	}

	clone := dfs(node)
	return clone
}

func makeNode(val, nsize int) *Node {
	return &Node{
		Val:       val,
		Neighbors: make([]*Node, nsize),
	}
}
```

* 22/22 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 49.17 % of golang submissions (4.7 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = nodes count, E = edges count

Time :  O(N + E)  -- visit each node once, traverse each edge twice
Space: O(N)       -- map + recursion stack (excluding the cloned graph itself)
```