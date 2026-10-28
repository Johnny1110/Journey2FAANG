/*
 * @lc app=leetcode id=155 lang=golang
 *
 * [155] Min Stack
 */

// @lc code=start
type MinStack struct {
	stack      []int
	minHistory []int // mins[i] = min of stack[0..i]
}

func Constructor() MinStack {
	return MinStack{}
}

func (this *MinStack) Len() int {
	return len(this.stack)
}

func (this *MinStack) Push(value int) {
	this.stack = append(this.stack, value)

	if len(this.minHistory) == 0 {
		this.minHistory = append(this.minHistory, value)
	} else {
		this.minHistory = append(this.minHistory, min(value, this.minHistory[len(this.minHistory)-1]))
	}
}

func (this *MinStack) Pop() {
	this.stack = this.stack[:this.Len()-1]
	this.minHistory = this.minHistory[:len(this.minHistory)-1]
}

func (this *MinStack) Top() int {
	return this.stack[this.Len()-1]
}

func (this *MinStack) GetMin() int {
	return this.minHistory[len(this.minHistory)-1]
}

/**
 * Your MinStack object will be instantiated and called as such:
 * obj := Constructor();
 * obj.Push(value);
 * obj.Pop();
 * param_3 := obj.Top();
 * param_4 := obj.GetMin();
 */
// @lc code=end

