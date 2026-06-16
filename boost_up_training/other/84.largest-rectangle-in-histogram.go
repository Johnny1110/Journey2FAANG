/*
 * @lc app=leetcode id=84 lang=golang
 *
 * [84] Largest Rectangle in Histogram
 */

// @lc code=start
type Stack []int

func (s Stack) size() int {
	return len(s)
}

func (s Stack) top() int {
	return s[s.size()-1]
}

func (s *Stack) pop() int {
	res := (*s)[s.size()-1]
	*s = (*s)[:s.size()-1]
	return res
}

func (s *Stack) push(val int) {
	*s = append(*s, val)
}

func largestRectangleArea(heights []int) int {
	best := 0
	stack := Stack([]int{})

	for i := 0; i < len(heights); i++ {
		for stack.size() > 0 && heights[stack.top()] >= heights[i] {
			// found right bound of stack.top
			poppedIdx := stack.pop()
			H := heights[poppedIdx]
			leftBound := -1
			if stack.size() > 0 {
				leftBound = stack.top()
			}

			W := i - leftBound - 1
			best = max(best, W*H)
		}

		// push i into stack
		stack.push(i)
	}

	// still got some element left in stack.
	for stack.size() > 0 {
		poppedIdx := stack.pop()
		H := heights[poppedIdx]
		rightBound := len(heights)
		leftBound := -1
		if stack.size() > 0 {
			leftBound = stack.top()
		}

		W := rightBound - leftBound - 1
		best = max(best, W*H)
	}

	return best
}

// @lc code=end

