# 73. Set Matrix Zeroes

<br>

---

<br>

## Coding

```go
type Direction int

const UP Direction = 1
const DOWN Direction = 2
const LEFT Direction = 3
const RIGHT Direction = 4

func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	var dfs func(d Direction, row, col int)
	dfs = func(d Direction, row, col int) {
		// return
		if row < 0 || row >= len(matrix) || col < 0 || col >= len(matrix[0]) {
			return
		}

		// change current spot
		matrix[row][col] = 0

		// calc next idx
		switch d {
		case UP:
			row--
		case DOWN:
			row++
		case LEFT:
			col--
		case RIGHT:
			col++
		}
		dfs(d, row, col)
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		dfs(UP, row, col)
		dfs(DOWN, row, col)
		dfs(LEFT, row, col)
		dfs(RIGHT, row, col)
	}
}
```

* 203/203 cases passed (65 ms)
* Your runtime beats 5.66 % of golang submissions
* Your memory usage beats 7.27 % of golang submissions (9.4 MB)


<br>
<br>

## Coding

```go
type Direction int

const UP Direction = 1
const DOWN Direction = 2
const LEFT Direction = 3
const RIGHT Direction = 4

func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	var dfs func(d Direction, row, col int)
	dfs = func(d Direction, row, col int) {
		// return
		if row < 0 || row >= len(matrix) || col < 0 || col >= len(matrix[0]) {
			return
		}

		// change current spot
		matrix[row][col] = 0

		// calc next idx
		switch d {
		case UP:
			row--
		case DOWN:
			row++
		case LEFT:
			col--
		case RIGHT:
			col++
		}
		dfs(d, row, col)
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		dfs(UP, row, col)
		dfs(DOWN, row, col)
		dfs(LEFT, row, col)
		dfs(RIGHT, row, col)
	}
}
```

<br>
<br>

## Coding - 2

```go
func setZeroes(matrix [][]int) {
	// find all 0 at first
	// dfs expolore.
	idxs := [][]int{} // could replace with 1D array.
	for i := 0; i < len(matrix); i++ {
		for j := 0; j < len(matrix[i]); j++ {
			if matrix[i][j] == 0 {
				idxs = append(idxs, []int{i, j})
			}
		}
	}

	for _, idx := range idxs {
		row, col := idx[0], idx[1]
		for i := 0; i < len(matrix); i++ {
			matrix[i][col] = 0
		}
		for i := 0; i < len(matrix[row]); i++ {
			matrix[row][i] = 0
		}
	}
}
```

* 203/203 cases passed (34 ms)
* Your runtime beats 5.66 % of golang submissions
* Your memory usage beats 5.05 % of golang submissions (11.2 MB)


<br>
<br>

## Time & Space Complexity

```
Let m = rows, n = cols, k = number of zeros

Coding-1 (DFS):
  Time:  O(m*n + k*(m+n)) — scan + 4-direction DFS per zero
  Space: O(k) for idxs + O(m+n) call stack per DFS

Coding-2 (final, .go file):
  Time:  O(m*n + k*(m+n)) — scan + zero full row & col per zero
         Worst case (all zeros): O(m*n*(m+n)) due to repeated work
  Space: O(k) — up to O(m*n) in the worst case
```

---

## Score: 5 / 10

### What you did well
- Correctly collected original zero positions **before** mutating the matrix — avoiding the classic bug of marking new zeros as original zeros.
- Coding-2 removed the unnecessary DFS and is much simpler than Coding-1. Good self-improvement!

### Issues

**1. Repeated work on shared rows/columns**

If two zeros share the same row, you zero that row twice (once per zero). Same for columns. In the worst case (all cells are 0) this makes the algorithm `O(m*n*(m+n))`.

**2. Extra space for `idxs`**

You can do this with `O(m+n)` or even `O(1)` extra space.

---

## Hint — can you improve further?

**Step 1 → O(m*n) time, O(m+n) space**

Instead of storing every zero coordinate, store only *which rows* and *which cols* need to be zeroed (two boolean arrays/sets of size m and n). Then do a second pass to zero them. Each row/col is zeroed exactly once → no repeated work.

```
rows[i] = true  // row i needs zeroing
cols[j] = true  // col j needs zeroing
```

**Step 2 → O(m*n) time, O(1) space** *(the optimal solution)*

Hint: the matrix itself has a first row and a first column. Can you repurpose them as your `rows[]` and `cols[]` markers instead of allocating extra arrays? Be careful about the first row/col themselves — handle them separately.

Try implementing Step 1 first, then Step 2 if you want the optimal result.