# 143. Reorder List

<br>

---

<br>

## Thinking

```
[1, 2, 3, 4]

// spilt from mid
[1, 2] 
[3, 4]

// reverse second linkedlist
[1, 2] 
[4, 3]

// merge two linkedlist 
[1, 4, 2, 3]
```

## Coding

```go
func reorderList(head *ListNode) {
	if head == nil || head.Next == nil {
		return
	}

	// 1. spilt from mid
	fast, slow := head, head
	for fast.Next != nil && fast.Next.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next
	}
	secHead := slow.Next
	slow.Next = nil // cut

	// 2. reverse second linkedlist
	ptA, ptB := secHead, secHead.Next
	secHead.Next = nil // clean
	var tmp *ListNode
	for ptB != nil {
		tmp = ptB.Next
		ptB.Next = ptA

		ptA = ptB
		ptB = tmp
	}
	secHead = ptA

	// 3. merge two linkedlist
	dummyHead := &ListNode{
		Val:  0,
		Next: nil,
	}

	tmp = dummyHead
	for head != nil && secHead != nil {
		a, b := head, secHead
		head = head.Next
		secHead = secHead.Next

		tmp.Next = a
		a.Next = b
		if b != nil {
			b.Next = nil
		}

		tmp = b
	}

	// final check
	if head != nil {
		tmp.Next = head
		tmp = head
	}
	if secHead != nil {
		tmp.Next = secHead
		tmp = secHead
	}
}
```

<br>
<br>

## Time & Space Complexity

```
Assume: N = length of ListNode

Time: O (N)
Space: O (1)
```

<br>
<br>

## Formatted Code

```go
func reorderList(head *ListNode) {
	if head == nil || head.Next == nil {
		return
	}

	// 1. spilt from mid
	fast, slow := head, head
	for fast.Next != nil && fast.Next.Next != nil {
		slow = slow.Next
		fast = fast.Next.Next
	}
	secHead := slow.Next
	slow.Next = nil // cut

	// 2. reverse second linkedlist
	var prev *ListNode
	for secHead != nil {
		next := secHead.Next
		secHead.Next = prev
		prev, secHead = secHead, next
	}

	// 3. merge two linkedlist
	first, second := head, prev
	for second != nil {
		n1, n2 := first.Next, second.Next
		first.Next = second
		second.Next = n1
		first, second = n1, n2
	}
}
```