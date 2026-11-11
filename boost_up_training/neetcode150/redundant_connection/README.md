# 684. Redundant Connection

<br>

---

<br>

## Desc

In this problem, a tree is an undirected graph that is connected and has no cycles.

You are given a graph that started as a tree with n nodes labeled from 1 to n, with one additional edge added. The added edge has two different vertices chosen from 1 to n, and was not an edge that already existed. The graph is represented as an array edges of length n where `edges[i] = [ai, bi]` indicates that there is an edge between nodes ai and bi in the graph.

Return an edge that can be removed so that the resulting graph is a tree of n nodes. If there are multiple answers, return the answer that occurs last in the input.

<br>
<br>

## Coding

```go
func findRedundantConnection(edges [][]int) []int {
	// n = node count
	n := len(edges) + 1

	// Union-Find
	parent := make([]int, n)
	// init parent
	for i := 0; i < n; i++ {
		parent[i] = i
	}

	var find func(i int) int
	find = func(i int) int {
		p := parent[i]
		if p == i {
			return p
		}

		p = find(p)
		parent[i] = p
		return p
	}

	union := func(a, b int) bool {
		pa, pb := find(a), find(b)
		if pa != pb {
			// different parent, can be merged
			parent[pa] = pb
			return true
		} else {
			// cicle found
			return false
		}
	}

	// main loop
	for _, e := range edges {
		if !union(e[0], e[1]) {
			return e
		}
	}

	return []int{}
}
```

* 40/40 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 16.75 % of golang submissions (5.7 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = len of edges

Time: O(N log N) -> Path compression | O(N²) worst case (the tree can become a long chain)
Space: O(N)
```

