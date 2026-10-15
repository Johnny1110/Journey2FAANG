/*
 * @lc app=leetcode id=146 lang=golang
 *
 * [146] LRU Cache
 */

// @lc code=start
type LRUCache struct {
	capacity int
	kvmap    map[int]*Node
	head     *Node
	tail     *Node
}

func Constructor(capacity int) LRUCache {
	head, tail := &Node{}, &Node{}
	head.Next = tail
	tail.Prev = head

	return LRUCache{
		capacity: capacity,
		kvmap:    make(map[int]*Node),
		head:     head,
		tail:     tail,
	}
}

func (this *LRUCache) Get(key int) int {
	node, exists := this.kvmap[key]
	if !exists {
		return -1
	}

	this.moveToFront(node)
	return node.Val
}

func (this *LRUCache) Put(key int, value int) {
	node, exists := this.kvmap[key]
	if exists {
		node.Val = value
		this.moveToFront(node)
		return
	}

	if this.reachedLimit() {
		// remove last
		lastNode := this.tail.Prev
		this.unlink(lastNode)
		delete(this.kvmap, lastNode.Key)
	}

	node = &Node{
		Key: key,
		Val: value,
	}

	// add into kvmap
	this.kvmap[key] = node
	this.pushFront(node)

}

func (this *LRUCache) reachedLimit() bool {
	return len(this.kvmap) >= this.capacity
}

func (this *LRUCache) unlink(node *Node) {
	node.Prev.Next = node.Next
	node.Next.Prev = node.Prev
}

func (this *LRUCache) pushFront(node *Node) {
	node.Prev, node.Next = this.head, this.head.Next
	this.head.Next.Prev = node
	this.head.Next = node
}

func (this *LRUCache) moveToFront(node *Node) {
	if this.head.Next == node {
		return
	}
	this.unlink(node)
	this.pushFront(node)
}

type Node struct {
	Key  int
	Val  int
	Prev *Node
	Next *Node
}

/**
 * Your LRUCache object will be instantiated and called as such:
 * obj := Constructor(capacity);
 * param_1 := obj.Get(key);
 * obj.Put(key,value);
 */
// @lc code=end

