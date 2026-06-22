# 2013. Detect Squares

<br>

---

<br>

## Coding - 1

```go
type DetectSquares struct {
	xAxis map[int][]int
	yAxis map[int][]int
}

func Constructor() DetectSquares {
	return DetectSquares{
		xAxis: make(map[int][]int),
		yAxis: make(map[int][]int),
	}
}

func (this *DetectSquares) Add(point []int) {
	x, y := point[0], point[1]

	// create if not exists
	if _, exists := this.xAxis[x]; !exists {
		this.xAxis[x] = []int{}
	}
	if _, exists := this.yAxis[y]; !exists {
		this.yAxis[y] = []int{}
	}
	// add in to ds
	this.xAxis[x] = append(this.xAxis[x], y)
	this.yAxis[y] = append(this.yAxis[y], x)
}

func (this *DetectSquares) Count(point []int) int {
	count := 0
	x, y := point[0], point[1]

	//fmt.Printf("count: %v \n", point)
	//fmt.Printf("this.xAxis = %v, this.yAxis = %v \n", this.xAxis, this.yAxis)

	// find all possible x --
	all_x, exists := this.yAxis[y]
	if !exists {
		//fmt.Printf("@1 \n")
		return 0
	}

	// point-2
	for _, _x := range all_x {
		width := distance(x, _x)
        if width == 0 {
            continue
        }

		all__y, exists := this.xAxis[_x]
		if !exists {
			continue
		}

		// point-3
		// use width to locate y
		for _, _y := range all__y {
			y_y := distance(y, _y)

			if y_y != width {
				continue
			}

			// found third point

			// point-4
			zall_x, exists := this.yAxis[_y]
			if !exists {
				continue
			}

			for _, xx := range zall_x {
				if xx == x {
					count++
				}
			}
		}

	}

	return count
}

func distance(a, b int) int {
	if a > b {
		return a - b
	} else {
		return b - a
	}
}
```

<br>

### Time Limit Exceeded

* 53/55 cases passed (N/A)

<br>
<br>

## Time & Space Complexity

```
Assume: n = input add counts
Time: O(n³)
Space: O(n)
```

<br>
<br>

## Coding - 2

```go
type DetectSquares struct {
	pcnt map[[2]int]int // [x, y] : count
	ybyx map[int][]int
}

func Constructor() DetectSquares {
	return DetectSquares{
		pcnt: make(map[[2]int]int),
		ybyx: make(map[int][]int),
	}
}

func (this *DetectSquares) Add(point []int) {
	x, y := point[0], point[1]
	p := [2]int{x, y}
	if this.pcnt[p] == 0 {
		this.ybyx[x] = append(this.ybyx[x], y)
	}
	this.pcnt[p]++
}

func (this *DetectSquares) Count(point []int) int {
	count := 0
	x, y := point[0], point[1]

	// TODO
	for _, y2 := range this.ybyx[x] {
		if y == y2 {
			continue // same point
		}

		side := distance(y, y2)

		// left side
		count += this.pcnt[[2]int{x - side, y}] * this.pcnt[[2]int{x - side, y2}] * this.pcnt[[2]int{x, y2}]
		// right side
		count += this.pcnt[[2]int{x + side, y}] * this.pcnt[[2]int{x + side, y2}] * this.pcnt[[2]int{x, y2}]
	}

	return count
}

func distance(a, b int) int {
	if a > b {
		return a - b
	} else {
		return b - a
	}
}
```

<br>

* 55/55 cases passed (19 ms)
* Your runtime beats 81.25 % of golang submissions
* Your memory usage beats 62.5 % of golang submissions (9.3 MB)

## Time & Space Complexity

```
Assume: n = input add counts
Time: O(n)
Space: O(n)
```

### Split Add and Count — they have different costs:

* `Add`: O(1) amortized — one map write, and the slice append amortizes to O(1).
* `Count`: O(k), where k = number of distinct y's at the query's column (len(ybyx[x])). Each iteration is constant work (a fixed set of lookups + arithmetic).