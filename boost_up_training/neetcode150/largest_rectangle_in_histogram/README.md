# 84. Largest Rectangle in Histogram

<br>

---

<br>

## Desc

Given an array of integers heights representing the histogram's bar height where the width of each bar is 1, 
return the area of the largest rectangle in the histogram.

## Coding

```go
func largestRectangleArea(heights []int) int {
	best := 0

	for i := 0; i < len(heights); i++ {
		H := heights[i]

		bestLeft, bestRight := i, i

		// find bestLeft
		for j := i; j >= 0; j-- {
			if heights[j] >= H {
				bestLeft = j
			} else {
				break
			}
		}

		// find bestRight
		for j := i; j < len(heights); j++ {
			if heights[j] >= H {
				bestRight = j
			} else {
				break
			}
		}
		W := bestRight - bestLeft + 1
		best = max(best, W*H)
	}

	return best
}
```

* Time Limit Exceeded
* 93/99 cases passed (N/A)

<br>
<br>

## Time & Space Complexity

```
Assume: length of heights = n
Time: O(n²) 
Space: O(1)
```


<br>

## Hint

你對題目的理解是正確的，暴力法也寫對了（93/99 過關說明邏輯沒問題）。只是 O(n²) 在最後 6 個大測資會超時，現在需要優化到 O(n)。


### 關鍵觀察：你重複掃描了什麼？

你的暴力法中，對每根柱子都要向左/向右重新掃一次找邊界。但很多掃描是重複的——如果你已經知道某根柱子是「矮柱子」，它會是它右邊所有更高柱子的左邊界。

**核心轉換**：與其對每根柱子找「左右第一個比我矮的」，不如反過來想——用一個資料結構在遍歷過程中**動態追蹤**還沒找到右邊界的柱子。


### 提示：單調遞增棧

想像你從左到右走過 histogram：

- 你遇到一根柱子，高度是 `h`。所有之前遇到、比 `h` **高**的柱子，它們的右邊界都找到了（就是 `h` 這根）。
- 那些比 `h` **矮或等於**的柱子，它們的右邊界還在更右邊，先留著。

這剛好是一個 **遞增棧（stack）** 的行為——棧裡永遠保持高度遞增。遇到矮柱子就 pop，pop 的時候計算面積。


試著用棧改寫看看。概念跟你的暴力法一致（找左右邊界 → 算面積），只是邊界查找從 O(n) 變成均攤 O(1)。

<br>

**幫你更具體一點，棧的操作邏輯是這樣：**

```
遍歷 i = 0..n-1:
    當 stack 非空 且 heights[i] < heights[stack.top()]:
        // 棧頂那根柱子找到右邊界了（就是 i）
        pop = stack.pop()
        h = heights[pop]
        左邊界 = stack 空了 ? -1 : stack.top()
        寬度 = i - 左邊界 - 1
        面積 = h * 寬度
    把 i push 進 stack
```

遍歷完之後，棧裡的柱子右邊界都是 `n`（陣列結尾），用同樣邏輯再清空一次。

---

試著把這段寫成 code，卡住再說。

<br>
<br>

## Coding - 2

```go
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
		for stack.size() > 0 && heights[stack.top()] > = heights[i] {
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
```


* 99/99 cases passed (4 ms)
* Your runtime beats 90.65 % of golang submissions
* Your memory usage beats 30.49 % of golang submissions (12.3 MB)


```
Assume: length of heights = n
Time: O(n) 
Space: O(n) -> stack size
```