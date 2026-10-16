/*
 * @lc app=leetcode id=150 lang=golang
 *
 * [150] Evaluate Reverse Polish Notation
 */

// @lc code=start
func evalRPN(tokens []string) int {
	stack := IntStack([]int{})

	for _, s := range tokens {
		if !isEval(s) {
			// push int into stack
			num, _ := strconv.Atoi(s)
			stack.Push(num)
		} else {
			// pop 2 int from stack and perform eval
			b, a := stack.Pop(), stack.Pop()
			c := calc(a, b, s)
			stack.Push(c)
		}
	}

	return stack.Pop()
}

func calc(a, b int, s string) int {
	switch s {
	case "+":
		return a + b
	case "-":
		return a - b
	case "*":
		return a * b
	case "/":
		return a / b
	}

	return 0
}

func isEval(s string) bool {
	return s == "+" || s == "-" || s == "*" || s == "/"
}

type IntStack []int

func (s IntStack) Len() int {
	return len(s)
}

func (s *IntStack) Push(val int) {
	*s = append(*s, val)
}

func (s *IntStack) Pop() int {
	old := *s
	val := old[len(old)-1]
	*s = old[:len(old)-1]
	return val
}

// @lc code=end

