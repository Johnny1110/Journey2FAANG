/*
 * @lc app=leetcode id=684 lang=golang
 *
 * [684] Redundant Connection
 */

// @lc code=start
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

// @lc code=end

