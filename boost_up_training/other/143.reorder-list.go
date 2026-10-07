/*
 * @lc app=leetcode id=143 lang=golang
 *
 * [143] Reorder List
 */

// @lc code=start
/**
 * Definition for singly-linked list.
 * type ListNode struct {
 *     Val int
 *     Next *ListNode
 * }
 */
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

// @lc code=end

