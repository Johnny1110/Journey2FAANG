# 1584. Min Cost to Connect All Points

<br>

---

<br>

## Desc

You are given an array points representing integer coordinates of some points on a 2D-plane, where points[i] = [xi, yi].

The cost of connecting two points [xi, yi] and [xj, yj] is the manhattan distance between them: |xi - xj| + |yi - yj|, where |val| denotes the absolute value of val.

Return the minimum cost to make all points connected. All points are connected if there is exactly one simple path between any two points.


## Coding

```go
func minCostConnectPoints(points [][]int) int {
	// build distance graph
	graph := buildGraph(points)
	result := 0

	// go Prim’s algorithm
	n := len(points)
	minDist := make([]int, n) // from j to tree, min cost
	visited := make([]bool, n)
	for i := range minDist {
		minDist[i] = math.MaxInt // init
	}

	minDist[0] = 0 // start from point 0, connecting it costs nothing

	for round := 0; round < n; round++ {
		// Step 1: find u = the unvisited point with the smallest minDist
		u := -1
		for j := 0; j < n; j++ {
			if !visited[j] && (u == -1 || minDist[u] > minDist[j]) {
				u = j
			}
		}
		// Step 2: add u to the tree
		result += minDist[u]
		visited[u] = true

		// Step 3: u is now in the tree, so update minDist for every unvisited v
		weights := graph[u]
		for v := 0; v < n; v++ {
			// update minDist
			if !visited[v] {
				minDist[v] = min(minDist[v], weights[v])
			}
		}
	}

	return result
}

func buildGraph(points [][]int) [][]int {
	graph := make([][]int, len(points))

	for i, pointA := range points {
		graph[i] = make([]int, len(points))
		for j, pointB := range points {
			graph[i][j] = distance(pointA, pointB)
		}
	}

	return graph
}

func distance(a, b []int) int {
	return abs(a[0]-b[0]) + abs(a[1]-b[1])
}

func abs(a int) int {
	if a < 0 {
		return -a
	}
	return a
}
```

* 72/72 cases passed (24 ms)
* Your runtime beats 77.14 % of golang submissions
* Your memory usage beats 74.29 % of golang submissions (12.7 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = len of points

Time: O(N square)
Space: O(N square)
```