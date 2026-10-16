# 150. Evaluate Reverse Polish Notation

<br>

---

<br>

## Example

Example 1:

```
Input: tokens = ["2","1","+","3","*"]
Output: 9
Explanation: ((2 + 1) * 3) = 9
```

Example 2:

```
Input: tokens = ["4","13","5","/","+"]
Output: 6
Explanation: (4 + (13 / 5)) = 6
```

Example 3:

```
Input: tokens = ["10","6","9","3","+","-11","*","/","*","17","+","5","+"]
Output: 22
Explanation: ((10 * (6 / ((9 + 3) * -11))) + 17) + 5
= ((10 * (6 / (12 * -11))) + 17) + 5
= ((10 * (6 / -132)) + 17) + 5
= ((10 * 0) + 17) + 5
= (0 + 17) + 5
= 17 + 5
= 22
```

<br>
<br>

## Coding

```go
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
```

* 23/23 cases passed (0 ms)
* Your runtime beats 100 % of golang submissions
* Your memory usage beats 95.09 % of golang submissions (5.9 MB)

<br>
<br>

## Time & SSpace Complexity

```
Assume: N = length of tokens

Time: O (N)
Space: O (N)
```