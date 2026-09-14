/*
 * @lc app=leetcode id=138 lang=golang
 *
 * [138] Copy List with Random Pointer
 */

// @lc code=start
/**
 * Definition for a Node.
 * type Node struct {
 *     Val int
 *     Next *Node
 *     Random *Node
 * }
 */

func copyRandomList(head *Node) *Node {

	nodeMap := make(map[*Node]*Node)

	var clone func(source *Node) *Node
	clone = func(source *Node) *Node {
		if source == nil {
			return nil
		}

		if nodeMap[source] != nil {
			return nodeMap[source]
		}

		cpNode := &Node{
			Val: source.Val,
		}

		nodeMap[source] = cpNode

		// Random:
		if source.Random != nil {
			cpNode.Random = clone(source.Random)
		}

		// Next
		if source.Next != nil {
			cpNode.Next = clone(source.Next)
		}

		return cpNode
	}

	return clone(head)
}

// @lc code=end

