/*
 * @lc app=leetcode id=1584 lang=golang
 *
 * [1584] Min Cost to Connect All Points
 */

// @lc code=start
type Edge struct {
	cost int
	a, b int
}

func minCostConnectPoints(points [][]int) int {
	n := len(points)

	allEdges := []*Edge{}

	for i := 0; i < n; i++ {
		for j := i + 1; j < n; j++ {
			pa, pb := points[i], points[j]

			edge := &Edge{
				cost: distance(pa, pb),
				a:    i,
				b:    j,
			}
			allEdges = append(allEdges, edge)
		}
	}

	// sort: order by cost
	sort.Slice(allEdges, func(a, b int) bool {
		return allEdges[a].cost < allEdges[b].cost
	})

	// Union-Find
	parents := make([]int, n)
	// init parent
	for i := 0; i < n; i++ {
		parents[i] = i
	}

	// find root
	var find func(i int) int
	find = func(i int) int {
		p := parents[i]
		if p == i {
			return p
		}
		parents[i] = find(p)
		return parents[i]
	}

	// union func
	union := func(i, j int) bool {
		rootOfI, rootOfJ := find(i), find(j)
		if rootOfI == rootOfJ {
			return false
		}
		// merge two group
		parents[rootOfI] = rootOfJ // merge: one root now points at the other
		return true
	}

	result := 0
	count := 0 // max connect count is n - 1
	// main loop
	for _, e := range allEdges {
		if union(e.a, e.b) {
			result += e.cost
			count++

			if count >= n-1 {
				break
			}
		}

	}

	return result
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

