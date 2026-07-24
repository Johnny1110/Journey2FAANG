/*
 * @lc app=leetcode id=1046 lang=golang
 *
 * [1046] Last Stone Weight
 */

// @lc code=start
func lastStoneWeight(stones []int) int {
	if len(stones) == 1 {
		return stones[0]
	}

	h := &MaxHeap{}

	for _, stone := range stones {
		heap.Push(h, stone)
	}

	for h.Len() > 1 {
		a, b := heap.Pop(h).(int), heap.Pop(h).(int)
		remaining := a - b
		if remaining > 0 {
			heap.Push(h, remaining)
		}
	}

	if h.Len() > 0 {
		return heap.Pop(h).(int)
	} else {
		return 0
	}

}

// Heap Implement
type MaxHeap []int

func (h MaxHeap) Len() int {
	return len(h)
}

func (h MaxHeap) Less(i, j int) bool {
	return h[i] > h[j]
}

func (h MaxHeap) Swap(i, j int) {
	h[i], h[j] = h[j], h[i]
}

// Push() & Pop()
func (h *MaxHeap) Push(val any) {
	*h = append(*h, val.(int))
}

func (h *MaxHeap) Pop() any {
	oldSlice := *h
	length := len(oldSlice)
	val := oldSlice[length-1]
	*h = oldSlice[:length-1]
	return val
}

// @lc code=end

