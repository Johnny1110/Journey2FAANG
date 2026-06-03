# 79. Word Search

<br>

---

<br>

## Desc

Given an `m x n` grid of characters board and a string word, return true if word exists in the grid.

The word can be constructed from letters of sequentially adjacent cells, where adjacent cells are horizontally or vertically neighboring. The same letter cell may not be used more than once.

## Coding - 1

```go
func exist(board [][]byte, word string) bool {
	m, n := len(board), len(board[0])
	// define dfs
	visited := make([][]bool, m)
	for i := 0; i < len(visited); i++ {
		visited[i] = make([]bool, n)
	}

	// dfs directions
	directions := [][]int{
		{1, 0},  // down
		{-1, 0}, // up
		{0, 1},  // right
		{0, -1}, // left
	}

	var dfs func(row, col, widx int) bool
	dfs = func(row, col, widx int) bool {
		targetLetter := word[widx]
		thisLetter := board[row][col]

		if targetLetter != thisLetter {
			return false
		}

		if widx == len(word)-1 {
			return true
		}

		visited[row][col] = true

		for _, dir := range directions {
			nextRow, nextCol := row+dir[0], col+dir[1]
			if nextRow < 0 || nextRow >= m || nextCol < 0 || nextCol >= n || visited[nextRow][nextCol] {
				continue
			}

			if dfs(nextRow, nextCol, widx+1) {
				return true
			}
		}

		// rollback visited
		visited[row][col] = false
		return false
	}

	for i := 0; i < m; i++ {
		for j := 0; j < n; j++ {
			if dfs(i, j, 0) {
				return true
			}
		}
	}

	return false
}
```

<br>
<br>

## Time & Space Complexity

```
Assume: m = size of board, n = len of word

Time: O(m*n * 3^L) — N cells, each DFS explores up to 3^L paths

Space: O(m*n) + O(L) — visited 2D array + DFS recursion stack (max depth = word length)
```

---

## Score & Feedback

**Score: 7 / 10**

### What's good
- DFS + backtracking pattern is correctly implemented — visited rollback on line 61 is spot on.
- Early termination: checks letter match before recursing, returns immediately when last char matches.
- Clean, readable code with clear variable names.

### What needs fixing

**1. Time Complexity is wrong.** You wrote `O(m*n)`, but backtracking DFS is exponential in word length. Worst case: from each of the N = m×n cells, DFS branches into up to 3 directions (4 neighbors minus the cell we came from), for word length L. Correct answer:

> **O(N × 3^L)** where N = m×n cells, L = len(word).

This is a critical mistake — in a FAANG interview, getting the complexity wrong on a backtracking problem would raise red flags.

**2. Space Complexity has a minor error.** DFS recursion depth is bounded by the word length L, not m. Should be:

> **O(N + L)** — visited array + recursion stack.

### Hints for optimization (optional redo)

- **Character frequency pruning**: Before DFS, check if every char in `word` appears enough times on the board. If the board has 3 'z's but the word needs 4, return false immediately.
- **Search from the rarer end**: If `word[0]` appears more often on the board than `word[L-1]`, reverse the word and search — this prunes the search tree earlier.
- **In-place marking (space O(1) extra)**: Instead of a visited array, temporarily overwrite `board[row][col]` with a sentinel (e.g. `'#'`) and restore after backtracking. Saves O(N) space, leaving only O(L) recursion stack. Mention this trade-off in interviews (modifies input vs saves memory).


## Refine

```go
func exist(board [][]byte, word string) bool {
	m, n := len(board), len(board[0])

	// dfs directions
	directions := [][]int{
		{1, 0},  // down
		{-1, 0}, // up
		{0, 1},  // right
		{0, -1}, // left
	}

	var dfs func(row, col, widx int) bool
	dfs = func(row, col, widx int) bool {
		targetLetter := word[widx]
		thisLetter := board[row][col]

		if targetLetter != thisLetter {
			return false
		}

		if widx == len(word)-1 {
			return true
		}

		board[row][col] = '#'

		for _, dir := range directions {
			nextRow, nextCol := row+dir[0], col+dir[1]
			if nextRow < 0 || nextRow >= m || nextCol < 0 || nextCol >= n || board[nextRow][nextCol] == '#' {
				continue
			}

			if dfs(nextRow, nextCol, widx+1) {
				return true
			}
		}

		// rollback visited
		board[row][col] = thisLetter
		return false
	}

	for i := 0; i < m; i++ {
		for j := 0; j < n; j++ {
			if dfs(i, j, 0) {
				return true
			}
		}
	}

	return false
}
```