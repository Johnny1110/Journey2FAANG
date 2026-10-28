# 155. Min Stack

<br>

---

<br>

## Coding

```go
type MinStack struct {
	stack      []int
	minHistory map[int]int
}

func Constructor() MinStack {
	return MinStack{
		stack:      []int{},
		minHistory: make(map[int]int),
	}
}

func (this *MinStack) Len() int {
	return len(this.stack)
}

func (this *MinStack) Push(value int) {
	this.stack = append(this.stack, value)
	currLen := this.Len()

	if currLen == 1 {
		this.minHistory[1] = value
	} else {
		prev := this.minHistory[currLen-1]
		this.minHistory[currLen] = min(prev, value)
	}
}

func (this *MinStack) Pop() {
	this.stack = this.stack[:this.Len()-1]
}

func (this *MinStack) Top() int {
	return this.stack[this.Len()-1]
}

func (this *MinStack) GetMin() int {
	currLen := this.Len()
	return this.minHistory[currLen]
}
```

* 46/46 cases passed (275 ms)
* Your runtime beats 10.61 % of golang submissions
* Your memory usage beats 60.24 % of golang submissions (15 MB)

<br>
<br>

## Time & Space Complexity

```
Assume: N = access times

Time: O(1)
Space: O(N)
```

<br>
<br>

## Improvement

```go
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
```