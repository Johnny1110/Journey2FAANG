# 206. Reverse Linked List

<br>


---

<br>

## Coding

```go
func reverseList(head *ListNode) *ListNode {
	var prev *ListNode
	curr := head

	for curr != nil {
		next := curr.Next

		curr.Next = prev
		prev = curr
		curr = next
	}

	return prev
}
```

* 28/28 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 18.58 % of golang submissions (5.2 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = len of linked list

Time: O(N)
Space: O(1)
```