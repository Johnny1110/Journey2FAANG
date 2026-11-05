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
	minDist := make([]int, n)
	visited := make([]bool, n)

	// init minDist
	for i := 1; i < n; i++ {
		minDist[i] = math.MaxInt
	}
	// first point is the root of the tree
	// minDist[0] = 0

	// step 1. find min cost in minDist
	for round := 0; round < n; round++ {
		u := -1 // target point index
		for i := 0; i < n; i++ {
			if !visited[i] && (u == -1 || minDist[i] < minDist[u]) {
				u = i
			}
		}

		// step 2. add u into tree and update visited
		result += minDist[u]
		visited[u] = true

		// step 3. update minDist
		weights := graph[u]
		for i := 0; i < n; i++ {
			minDist[i] = min(minDist[i], weights[i])
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

<br>
<br>