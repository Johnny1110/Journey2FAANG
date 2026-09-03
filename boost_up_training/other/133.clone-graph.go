/*
 * @lc app=leetcode id=133 lang=golang
 *
 * [133] Clone Graph
 */

// @lc code=start
/**
 * Definition for a Node.
 * type Node struct {
 *     Val int
 *     Neighbors []*Node
 * }
 */

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

// @lc code=end

