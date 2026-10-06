# 141. Linked List Cycle

<br>

---

<br>

Return true if there is a cycle in the linked list. Otherwise, return false.

## Coding

```go
func hasCycle(head *ListNode) bool {
	slow, fast := head, head
	for fast != nil && fast.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next

		if slow == fast {
			return true
		}
	}

	return false
}
```

* 29/29 cases passed (7 ms)
* Your runtime beats 62.12 % of golang submissions
* Your memory usage beats 81.44 % of golang submissions (6.2 MB)

<br>
<br>

## Time and Space Compelxity

```
Assume: N = Length of nodeList

Time: O(N) No cycle: fast reaches the end in about N/2 iterations.
Space: O(1)
```