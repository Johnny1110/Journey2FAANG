# 138. Copy List with Random Pointer

<br>

---

<br>

## Coding

```go
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
		cpNode.Random = clone(source.Random)
        cpNode.Next = clone(source.Next)

		return cpNode
	}

	return clone(head)
}
```

<br>

* 19/19 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 22.54 % of golang submissions (5.5 MB)


<br>
<br>

## Time & Space Compelxity

```
Assume: N = node count

Time: O(N) 
Space: O(N) -> max call stack is N , and nodeMap contains N nodes at most.
```