/*
 * @lc app=leetcode id=2013 lang=golang
 *
 * [2013] Detect Squares
 */

// @lc code=start
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

/**
 * Your DetectSquares object will be instantiated and called as such:
 * obj := Constructor();
 * obj.Add(point);
 * param_2 := obj.Count(point);
 */
// @lc code=end

