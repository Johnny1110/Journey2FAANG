# 621. Task Scheduler

<br>

---

<br>

__Greedy rule is__: always run the available task with the largest remaining count.

<br>
<br>

## Coding

```go
type MaxHeap []int

func (h MaxHeap) Len() int           { return len(h) }
func (h MaxHeap) Less(i, j int) bool { return h[i] > h[j] }
func (h MaxHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i] }
func (h *MaxHeap) Push(val any) {
	*h = append(*h, val.(int))
}
func (h *MaxHeap) Pop() any {
	val := (*h)[h.Len()-1]
	*h = (*h)[:h.Len()-1]
	return val
}

type Task struct {
	cnt     int
	readyAt int
}

func leastInterval(tasks []byte, n int) int {
	queue := []*Task{}    // cooldown list
	H := MaxHeap([]int{}) // ready to join

	// collect task count only A~Z
    // O(n)
	var taskCnts [26]int
	for _, task := range tasks {
		num := task - 'A'
		taskCnts[num]++
	}

	// fill-in heap
    // 26 * O(log n)
	for _, cnt := range taskCnts {
		if cnt > 0 {
			heap.Push(&H, cnt)
		}
	}

	times := 0
	for len(queue) > 0 || H.Len() > 0 {
		times++

		if H.Len() > 0 {
			// pop a ready task slice to join.
			tCnt := heap.Pop(&H).(int) // O (log n)
			if tCnt-1 > 0 {
				task := &Task{cnt: tCnt - 1, readyAt: times + n}
				queue = append(queue, task) // O(1)
			}
		}

		// check task cooldown list
		if len(queue) > 0 && queue[0].readyAt == times {
			// found a ready task.
			tCnt := queue[0].cnt
			// pop queue
			queue = queue[1:len(queue)] // O(1)
			// push into heap
			heap.Push(&H, tCnt) // O (log n)
		}
	}

	return times
}
```

<br>

* 72/72 cases passed (26 ms)
* Your runtime beats 38.4 % of golang submissions
* Your memory usage beats 6.8 % of golang submissions (9.6 MB)

<br>

## Time & Space Complexity

```
Assume: all tasks count = N

Time: O(N + idles) × O(log 26)
Space: O(26) -> max size of queue and max heap is 26
```