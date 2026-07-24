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