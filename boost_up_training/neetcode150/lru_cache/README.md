# 146. LRU Cache

<br>

---

<br>

## Coding

```go
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

func (this *LRUCache) moveToFront(node *Node) {
    // remove node
	node.Prev.Next = node.Next
	node.Next.Prev = node.Prev

    // put node to front
	tmp := this.head.Next
	this.head.Next = node
	node.Next = tmp
	tmp.Prev = node
	node.Prev = this.head
}

func (this *LRUCache) Put(key int, value int) {
	node, exists := this.kvmap[key]
	if exists {
		node.Val = value

		this.moveToFront(node)
        return
	} else {
		node = &Node{
			Key: key,
			Val: value,
		}

		if this.reachedLimit() {
			// remove last
			lastNode := this.tail.Prev
			lastNode.Prev.Next = this.tail
			this.tail.Prev = lastNode.Prev
			delete(this.kvmap, lastNode.Key)
		}

		// add into kvmap
		this.kvmap[key] = node

	}
}

func (this *LRUCache) reachedLimit() bool {
	return len(this.kvmap) >= this.capacity
}

type Node struct {
	Key  int
	Val  int
	Prev *Node
	Next *Node
}
```

* 23/23 cases passed (36 ms)
* Your runtime beats 6.67 % of golang submissions
* Your memory usage beats 22.67 % of golang submissions (14.6 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = Capacity

Time: Put - O(1) Get - O(1)
Space: O(N) N nodes and n length of knmap
```

<br>
<br>

## Clean Code

```go
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
```