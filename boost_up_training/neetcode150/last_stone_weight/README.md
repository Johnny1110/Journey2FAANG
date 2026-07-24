# 1046. Last Stone Weight

<br>

---

<br>

## Coding 

```go
func lastStoneWeight(stones []int) int {
	if len(stones) == 1 {
		return stones[0]
	}

	// 1. sort stones
	slices.SortFunc(stones, func(a, b int) int { return cmp.Compare(b, a) })

	x := 1
	for y := 0; y < len(stones); y++ {
		weightX, weightY := stones[x], stones[y]
		remainingWeight := weightY - weightX

		// replace x position
		stones[x] = remainingWeight

		if remainingWeight > 0 {
			// bubble sort:
			for i := x + 1; i < len(stones); i++ {
				if stones[i-1] < stones[i] {
					tmp := stones[i]
					stones[i] = stones[i-1]
					stones[i-1] = tmp
				} else {
					break
				}
			}
		}

		if remainingWeight == 0 {
			x++
			y++
		}

		x++

		if x >= len(stones) {
			break
		}
	}

	return stones[len(stones)-1]
}
```

* 74/74 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 45.5 % of golang submissions (4 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = length of stones

Time: O(N次方) 最壞情況
Space: O(1)
```

<br>
<br>

## Enhancement -> Max Heap

```go
func lastStoneWeight(stones []int) int {
	if len(stones) == 1 {
		return stones[0]
	}

	h := MaxHeap(stones)
    heap.Init(&h)

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
```

* 74/74 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 45.5 % of golang submissions (3.9 MB)


<br>
<br>

## Time & Space Complexity

```
Assume: n = length of stones

Time: O(n log n) 
Space: O(n)
```

