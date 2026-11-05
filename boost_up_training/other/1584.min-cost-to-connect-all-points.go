/*
 * @lc app=leetcode id=1584 lang=golang
 *
 * [1584] Min Cost to Connect All Points
 */

// @lc code=start
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

// @lc code=end

